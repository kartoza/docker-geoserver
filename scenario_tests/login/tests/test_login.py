import requests
import unittest
from os import environ


class TestGeoServerREST(unittest.TestCase):

    def setUp(self):
        # Login to GeoServer and get the authentication cookies
        self.base_url = 'http://localhost:8080/geoserver'
        self.login_url = f'{self.base_url}/j_spring_security_check'
        self.container_name = environ['CONTAINER_NAME']
        credential_map = {
            'geoserver': {
                'username': 'admin',
                'password': environ['GEOSERVER_ADMIN_PASSWORD']
            },
            'credentials': {
                'username': 'myadmin',
                'password': environ['GEOSERVER_ADMIN_PASSWORD']
            },
            'server': {
                'username': 'admin',
                'password': self._read_password_file('/opt/geoserver/data_dir/security/pass.txt')
            }
        }

        creds = credential_map.get(self.container_name)
        if not creds:
            raise ValueError(f"Unknown container: {self.container_name}")

        self.username = creds['username']
        self.password = creds['password']

        self.session = requests.Session()
        login_data = {
            'username': self.username,
            'password': self.password,
            'submit': 'Login'
        }
        response = self.session.post(self.login_url, data=login_data)
        self.assertEqual(response.status_code, 200)

    def _read_password_file(self, path):
        with open(path, 'r') as file:
            return file.read().strip()

    def test_rest_endpoints_accessible(self):
        # Test if the REST endpoints are accessible as a logged user
        url = f'{self.base_url}/rest/workspaces.json'
        response = self.session.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json())

    def tearDown(self):
        # Logout from GeoServer
        logout_url = f'{self.base_url}/j_spring_security_logout'
        response = self.session.post(logout_url)
        self.assertEqual(response.status_code, 200)
