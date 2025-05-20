import requests
import unittest
from os import environ


class TestGeoServerREST(unittest.TestCase):

    def setUp(self):
        # Login to GeoServer and get the authentication cookies
        self.base_url = 'http://localhost:8080/geoserver'
        self.login_url = f'{self.base_url}/j_spring_security_check'
        self.container_name = environ['CONTAINER_NAME']

        if self.container_name =='users':

            split_username = environ['GEOSERVER_ADMIN_USER'].split(',')
            split_password = environ['GEOSERVER_ADMIN_PASSWORD'].split(',')
            credentials = dict(zip(split_username, split_password))
            for username, password in credentials.items():

                self.session = requests.Session()
                login_data = {
                    'username': username,
                    'password': password,
                    'submit': 'Login'
                }
                response = self.session.post(self.login_url, data=login_data)
                self.assertEqual(response.status_code, 200)
        else:
            if self.container_name == 'geoserver':
                self.password = environ['GEOSERVER_ADMIN_PASSWORD']
                self.username = 'admin'
            elif self.container_name == 'credentials':
                self.password = environ['GEOSERVER_ADMIN_PASSWORD']
                self.username = 'myadmin'
            elif self.container_name == 'server':
                self.username = 'admin'
                with open('/opt/geoserver/data_dir/security/pass.txt', 'r') as file:
                    file_pass = file.read()
                self.password = file_pass.replace("\n", "")
            self.session = requests.Session()
            login_data = {
                'username': self.username,
                'password': self.password,
                'submit': 'Login'
            }
            response = self.session.post(self.login_url, data=login_data)
            self.assertEqual(response.status_code, 200)

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