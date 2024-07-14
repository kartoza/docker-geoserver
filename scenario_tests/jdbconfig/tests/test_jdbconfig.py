import unittest
from os import environ, remove
from psycopg2 import connect, OperationalError
from requests import get
from PIL import Image


class TestGeoServerJDBCONFIG(unittest.TestCase):

    def setUp(self):
        self.gs_url = 'http://localhost:8080/geoserver'
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
            query = "SELECT EXISTS (SELECT 1 FROM workspace WHERE name = 'topp');"
            cursor.execute(query)
            table_exists = cursor.fetchone()[0]
        self.assertTrue(table_exists, "Workspace 'topp' does not exist")
        wms_request = f'{self.gs_url}/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=31.31110495617180689,\
                -101.7342329829540404,32.41516971387711976,-99.82891832338629001&CRS=EPSG:4326&WIDTH=1564&HEIGHT=906\
                &LAYERS=topp:states&STYLES=&FORMAT=image/png&DPI=96 &TILED=true \
                &MAP_RESOLUTION=96&FORMAT_OPTIONS=dpi:96&TRANSPARENT=TRUE'
        response = get(wms_request)
        with open('output.png', 'wb') as f:
            f.write(response.content)

        try:
            img = Image.open('output.png')
            img.verify()
            valid_image = True
        except (IOError, Image.DecompressionBombError):
            valid_image = False
        remove('output.png')

        # Verify that the seeding was successful
        self.assertEqual(response.status_code, 200)
        self.assertTrue(valid_image)

    def tearDown(self):
        self.db_conn.close()


if __name__ == '__main__':
    unittest.main()
