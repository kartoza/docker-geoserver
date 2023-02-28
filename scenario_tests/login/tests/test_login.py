import requests
import unittest


class TestGeoServerREST(unittest.TestCase):

    def setUp(self):
        # Login to GeoServer and get the authentication cookies
        self.base_url = 'http://localhost:8080/geoserver'
        self.login_url = f'{self.base_url}/j_spring_security_check'
        self.username = 'admin'
        self.password = 'myawesomegeoserver'
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
