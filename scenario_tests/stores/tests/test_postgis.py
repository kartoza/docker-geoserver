import unittest
from geoserver.catalog import Catalog
from geoserver.support import DimensionInfo


class TestGeoServer(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL and credentials
        self.gs_url = 'http://localhost:8080/geoserver'
        self.gs_user = 'admin'
        self.gs_password = 'myawesomegeoserver'

        # Define the name and parameters for the PostGIS store and layer
        self.store_name = 'demo_pg'
        self.dbname = 'gis'
        self.host = 'db'
        self.port = '5432'
        self.schema = 'public'
        self.user = 'docker'
        self.password = 'docker'
        self.table_name = 'world'
        self.layer_name = 'world'

        # Connect to the GeoServer catalog
        self.cat = Catalog(self.gs_url, self.gs_user, self.gs_password)

    def test_postgis_store(self):
        # Define the PostGIS store parameters
        params = {
            'host': self.host,
            'port': self.port,
            'database': self.dbname,
            'schema': self.schema,
            'user': self.user,
            'passwd': self.password,
            'dbtype': 'postgis',
        }

        # Create the PostGIS store
        store = self.cat.create_datastore(self.store_name, workspace=self.cat.get_workspace('kartozagis'))
        store.connection_parameters.update(params)
        store.save()

        # Define the layer parameters
        layer_params = {
            'name': self.layer_name,
            'title': self.layer_name,
            'store': store,
            'projection': 'EPSG:4326',
            'workspace': self.cat.get_workspace('kartozagis'),
            'advertised': True,
        }

        # Create the layer
        layer = self.cat.create_featuretype(self.table_name, **layer_params)
        layer.save()

        # Check that the layer was created with the correct name and projection
        self.assertEqual(layer.name, self.layer_name)
        self.assertEqual(layer.projection, 'EPSG:4326')

    def tearDown(self):
        # Delete the PostGIS store and layer
        self.cat.delete(self.cat.get_layer(self.layer_name))
        self.cat.delete(self.cat.get_store(self.store_name))


if __name__ == '__main__':
    unittest.main()
