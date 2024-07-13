import unittest
from os import environ, chown
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
        chown(vrt_path, 1000, 1000)

        geo = Geoserver(self.gs_url, username=self.geo_username, password=self.geo_password)

        auth = HTTPBasicAuth(self.geo_username, self.geo_password)

        # Create a workspace if it doesn't exist

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

        # Check that the published layer exists
        layer_source_url = f'{self.gs_url}/{self.geo_workspace_name}/wms?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&FORMAT=image/jpeg&TRANSPARENT=true&STYLES&LAYERS={self.geo_workspace_name}:{self.store_name}&exceptions=application/vnd.ogc.se_inimage&SRS=EPSG:26713&WIDTH=768&HEIGHT=578&BBOX=594739.7048312925,4919224.415741393,602069.4450795503,4924731.264860202'
        response = get(layer_source_url)

        # Check that the response has a status code of 200 (OK)
        self.assertEqual(response.status_code, 200)


if __name__ == '__main__':
    unittest.main()
