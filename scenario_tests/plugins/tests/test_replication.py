import unittest
from utils.utils import DBConnection


class TestReplicationMaster(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def test_create_new_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                CREATE TABLE IF NOT EXISTS test_replication_table (
                    id integer not null
                        constraint pkey primary key,
                    geom geometry(Point, 4326),
                    name varchar(30),
                    alias varchar(30),
                    description varchar(255)
                );
                """
            )

            c.execute(
                """
                INSERT INTO test_replication_table (id, geom, name, alias, description)
                VALUES 
                (
                    1,
                    st_setsrid(st_point(107.6097, 6.9120), 4326),
                    'Bandung',
                    'Paris van Java',
                    'Asia-Africa conference was held here'                     
                ) ON CONFLICT DO NOTHING;
                """
            )


class TestReplicationNode(unittest.TestCase):

    def setUp(self):
        self.db = DBConnection()

    def test_read_data(self):
        # create new table
        self.db.conn.autocommit = True
        with self.db.cursor() as c:
            c.execute(
                """
                SELECT * FROM test_replication_table;
                """
            )

            rows = c.fetchall()
            self.assertEqual(len(rows), 1)

