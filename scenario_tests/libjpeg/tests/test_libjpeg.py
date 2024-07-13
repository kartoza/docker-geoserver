import unittest
from requests import get
from parameterized import parameterized
from PIL import Image
from os import remove

class TestGeoServerTURBO(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        self.geo_workspace_name = 'topp'

    @parameterized.expand([
        ('jpeg',),
        ('vnd.jpeg-png',),
        ('vnd.jpeg-png8',),
    ])
    def test_wms_vector_layer(self, output):
        layer_name = '%s:states' % self.geo_workspace_name
        wms_request = f'{self.gs_url}/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=31.31110495617180689,\
            -101.7342329829540404,32.41516971387711976,-99.82891832338629001&CRS=EPSG:4326&WIDTH=1564&HEIGHT=906\
            &LAYERS=%s&STYLES=&FORMAT=image/%s&DPI=96 &TILED=true \
            &MAP_RESOLUTION=96&FORMAT_OPTIONS=dpi:96&TRANSPARENT=TRUE' % (layer_name, output)
        response = get(wms_request)

        # Save the response as a JPEG file
        with open('output.jpg', 'wb') as f:
            f.write(response.content)

        try:
            img = Image.open('output.jpg')
            img.verify()
            valid_image = True
        except (IOError, Image.DecompressionBombError):
            valid_image = False
        remove('output.jpg')
        # Verify that the wms request was successful
        self.assertEqual(response.status_code, 200)
        self.assertTrue(valid_image)


if __name__ == '__main__':
    unittest.main()
