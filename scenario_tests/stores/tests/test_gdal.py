import unittest
from os import environ
from subprocess import check_call
from requests import get, post, exceptions
from requests.auth import HTTPBasicAuth
from geo.Geoserver import Geoserver

class TestGeoServerGDAL(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        self.store_name = 'sfdem'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.geo_workspace_name = 'kartoza'
        self.geo_data_dir = '/usr/local/tomcat/data/data/sf'

    def test_publish_gdal_store(self):
        # Generate tiles
        built_vrt = f'gdalbuildvrt {self.geo_data_dir}/sfdem.vrt {self.geo_data_dir}/sfdem.tif'
        check_call(built_vrt, shell=True)
        vrt_path = f'{self.geo_data_dir}/sfdem.vrt'

        geo = Geoserver(self.gs_url, username=self.geo_username, password=self.geo_password)

        auth = HTTPBasicAuth(self.geo_username, self.geo_password)

        # Create a workspace if it doesn't exist
        try:
            rest_url = f'{self.gs_url}/rest/workspaces/{self.geo_workspace_name}.json'
            response = get(rest_url, auth=auth)
            response.raise_for_status()
        except exceptions.HTTPError:
            geo.create_workspace(workspace=self.geo_workspace_name)
            geo.set_default_workspace(self.geo_workspace_name)

        # Create a GDAL store
        store_data = f'''
            <coverageStore>
                <name>{self.store_name}</name>
                <workspace>{self.geo_workspace_name}</workspace>
                <enabled>true</enabled>
                <type>VRT</type>
            </coverageStore>
        '''
        store_url = f'{self.gs_url}/rest/workspaces/{self.geo_workspace_name}/coveragestores'
        response = post(store_url, data=store_data, auth=auth, headers={'Content-Type': 'application/xml'})
        self.assertEqual(response.status_code, 201)

        # Upload the VRT file to the store
        vrt_upload_url = f'{self.gs_url}/rest/workspaces/{self.geo_workspace_name}/coveragestores/{self.store_name}/external.vrt?configure=first&coverageName={self.store_name}'
        curl_command = f'curl -u {self.geo_username}:{self.geo_password} -v -XPUT -H "Content-type: text/plain" -d "file:{vrt_path}" {vrt_upload_url}'
        check_call(curl_command, shell=True)

        # Check that the data store exists
        data_store_url = f'{self.gs_url}/rest/workspaces/{self.geo_workspace_name}/datastores/{self.store_name}.json'
        response = get(data_store_url, auth=auth)
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()
