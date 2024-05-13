import unittest
from os import environ
from requests import get, exceptions
from requests.auth import HTTPBasicAuth


class GeoServerClusteringNode(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        # Define the PostGIS store name
        self.store_name = 'gis'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.geo_workspace_name = 'demo'

    def check_workspace_exists(self, auth):
        rest_url = '%s/rest/workspaces/%s.json' % (self.gs_url, self.geo_workspace_name)
        response = get(rest_url, auth=auth)
        return response.status_code == 200

    def check_data_store_exists(self, auth):
        data_source_url = '%s/rest/workspaces/%s/datastores/%s.json' % (
            self.gs_url, self.geo_workspace_name, self.store_name)
        response = get(data_source_url, auth=auth)
        return response.status_code == 200

    def check_layer_exists(self, auth, layer_name):
        layer_url = '%s/rest/workspaces/%s/layers/%s.json' % (
            self.gs_url, self.geo_workspace_name, layer_name)
        response = get(layer_url, auth=auth)
        return response.status_code == 200

    def check_style_exists(self, auth, layer_name):
        style_url = '%s/rest/workspaces/%s/styles/%s.json' % (
            self.gs_url, self.geo_workspace_name, layer_name)
        response = get(style_url, auth=auth)
        return response.status_code == 200

    def test_workspace_exists(self):
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        workspace_exists = self.check_workspace_exists(auth)
        self.assertTrue(workspace_exists, "Workspace does not exist")

    def test_data_store_exists(self):
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        data_store_exists = self.check_data_store_exists(auth)
        self.assertTrue(data_store_exists, "Data store does not exist")

    def test_layer_exists(self):
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        layer_name = 'states'
        layer_exists = self.check_layer_exists(auth, layer_name)
        self.assertTrue(layer_exists, "Layer does not exist")

    def test_layer_style_exists(self):
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        layer_name = 'states'
        layer_exists = self.check_style_exists(auth, layer_name)
        self.assertTrue(layer_exists, "Style does not exist")


if __name__ == '__main__':
    unittest.main()
