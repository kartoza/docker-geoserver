from time import sleep

import psycopg2
import unittest
from utils.utils import DBConnection


class TestReplicationPublisher(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def test_create_new_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                CREATE TABLE IF NOT EXISTS block (
                    id serial NOT NULL primary key,
                    geom geometry(Point,4326),
                    tile_name character varying,
                    location character varying
                );
                """
            )

            # Add table to publication if it doesn't included already
            # Using PL/PGSQL
            c.execute(
                """
                do
                $$
                begin
                    if not exists(
                            select * from pg_publication_tables 
                            where tablename = 'block' 
                            and pubname = 'logical_replication') then
                        alter publication logical_replication add table block;
                    end if;
                end;
                $$
                """
            )

            c.execute(
                """
                INSERT INTO block (id, geom, tile_name, location)
                VALUES 
                (
                    1,
                    st_setsrid(st_makepoint(107.6097, 6.9120),4326),
                    '2956BC',
                    'Oceanic'                     
                ) ON CONFLICT (id) DO NOTHING;
                """
            )


class TestReplicationSubscriber(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    @classmethod
    def assert_in_loop(
            cls, func_action, func_assert,
            back_off_limit=5, base_seconds=2, const_seconds=5):
        retry = 0
        last_error = None
        while retry < back_off_limit:
            try:
                output = func_action()
                func_assert(output)
                print('Assertion success')
                return
            except Exception as e:
                last_error = e
                print(e)
            retry += 1
            print('Retry [{}]. Attempting to try again later.'.format(
                retry))
            sleep(const_seconds + base_seconds ** retry)
        raise last_error

    def test_read_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                CREATE TABLE IF NOT EXISTS public.block (
                id serial NOT NULL primary key ,
                geom public.geometry(Point,4326),
                fid bigint,
                tile_name character varying,
                location character varying
                );
                """
            )

            # Hardcoded because the replication is setup using manual query
            publisher_conn_string = 'host=pg-publisher port=5432 ' \
                                    'password=docker user=docker dbname=gis'

            # Subscribe to the table that is published if it doesn't
            # subscribed already
            try:
                # Apparently create subscription cannot run inside
                # a transaction block.
                # So we run it without transaction block
                c.execute(
                    f"""
                    create subscription logical_subscription
                        connection '{publisher_conn_string}'
                        publication logical_replication
                    """
                )
                # Make sure that new changes are replicated immediately.
                c.execute(
                    """
                    alter subscription logical_subscription 
                    refresh publication
                    """
                )
            except Exception as e:
                print(e)

            # We don't know when the changes are sync'd so we loop the test
            # Testing insertion sync
            print('Insertion sync test')
            self.assert_in_loop(
                lambda : c.execute(
                    """
                    SELECT * FROM block
                    """
                ) or c.fetchall(),
                lambda _rows: self.assertEqual(len(_rows), 1)
            )

            # Testing update sync
            print('Update sync test')
            publisher_conn = psycopg2.connect(publisher_conn_string)
            publisher_conn.autocommit = True
            with publisher_conn.cursor() as publisher_c:
                publisher_c.execute(
                    """
                    UPDATE block set location = 'Oceanic territory' 
                    WHERE id = 1
                    """
                )
            self.assert_in_loop(
                lambda : c.execute(
                    """
                    SELECT location FROM block WHERE id = 1;
                    """
                ) or c.fetchone(),
                lambda _rows: self.assertEqual(
                    _rows[0], 'Oceanic territory')
            )

            # Testing delete sync
            print('Delete sync test')
            with publisher_conn.cursor() as publisher_c:
                publisher_c.execute(
                    """
                    DELETE FROM block WHERE id = 1
                    """
                )

            self.assert_in_loop(
                lambda: c.execute(
                    """
                    SELECT * FROM block
                    """
                ) or c.fetchall(),
                lambda _rows: self.assertEqual(len(_rows), 0)
            )
