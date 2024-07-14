import time
import unittest
from os import environ, remove
from PIL import Image
from requests import get, post
from requests.auth import HTTPBasicAuth


class TestGeoServerGWC(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        self.store_name = 'states_shapefile'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.geo_workspace_name = 'topp'

    def test_seed_vector_layer(self):
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)

        # Seed the vector layer

        layer_name = '%s:states' % self.geo_workspace_name
        gwc_url = f'{self.gs_url}/gwc/rest/seed/%s.xml' % layer_name

        # Set the GWC seed request parameters
        headers = {'Content-type': 'text/xml'}
        data = '<seedRequest><name>%s</name><srs><number>4326</number></srs><zoomStart>1</zoomStart>' \
               '<zoomStop>6</zoomStop><format>image/png</format><type>seed</type><threadCount>2</threadCount>' \
               '<parameterFilters>cql_filter:STATE_ABBR=\'TX\'</parameterFilters></seedRequest>' % layer_name

        post(gwc_url, headers=headers, data=data, auth=auth)

        time.sleep(30)
        wms_request = f'{self.gs_url}/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=31.31110495617180689,\
        -101.7342329829540404,32.41516971387711976,-99.82891832338629001&CRS=EPSG:4326&WIDTH=1564&HEIGHT=906\
        &LAYERS=%s&STYLES=&FORMAT=image/png&DPI=96 &TILED=true \
        &MAP_RESOLUTION=96&FORMAT_OPTIONS=dpi:96&TRANSPARENT=TRUE' % layer_name
        response = get(wms_request)

        # Save the response as a JPEG file
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


if __name__ == '__main__':
    unittest.main()
