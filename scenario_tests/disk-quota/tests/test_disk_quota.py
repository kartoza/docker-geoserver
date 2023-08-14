import unittest
from os import environ
from psycopg2 import connect, OperationalError


class TestGeoServerDISKQUOTA(unittest.TestCase):

    def setUp(self):
        self.db_schema = environ.get('POSTGRES_SCHEMA', 'public')
        try:
            self.db_conn = connect(
                dbname=environ.get('POSTGRES_DB', 'gis'),
                user=environ.get('POSTGRES_USER', 'docker'),
                password=environ.get('POSTGRES_PASS', 'docker'),
                host=environ.get('HOST', 'db'),
                port=environ.get('POSTGRES_PORT', 5432),
                sslmode=environ.get('SSL_MODE', 'allow')
            )
        except OperationalError as e:
            self.fail(f"Failed to connect to the database: {e}")

    def test_seed_vector_layer(self):

        with self.db_conn.cursor() as cursor:
            query = "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tilepage' \
            and table_schema = '%s');" % self.db_schema
            cursor.execute(query)
            table_exists = cursor.fetchone()[0]
        self.assertTrue(table_exists, "Table 'tilepage' does not exist")

    def tearDown(self):
        self.db_conn.close()


if __name__ == '__main__':
    unittest.main()
