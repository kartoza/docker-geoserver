import unittest
import requests
from requests.auth import HTTPBasicAuth
from os import environ, mkdir, chmod
from os.path import join, exists
from shutil import chown
import json
import time


class TestGeoServerBackup(unittest.TestCase):

    def setUp(self):
        """Set up the base URL, authentication, and create the zip file."""
        self.gs_url = 'http://localhost:8080/geoserver'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.username = 'geoserveruser'
        self.group_name = 'geoserverusers'
        self.backup_path = "/settings/backup/"

    def test_create_backup(self):
        """Test creating a GeoServer backup using the Backup and Restore plugin."""
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        base_url = f"{self.gs_url}/rest/br/backup/"
        if not exists(self.backup_path):
            mkdir(self.backup_path)
        backup_file = join(self.backup_path, 'geoserver.zip')
        # Create the empty zip file
        with open(backup_file, "wb") as f:
            pass

        # Change ownership of the zip file
        chmod(self.backup_path, 0o777)
        chown(backup_file, user=self.username, group=self.group_name)
        headers = {
            "Content-Type": "application/json"
        }

        payload = {
            "backup": {
                "archiveFile": backup_file,
                "overwrite": True,
                "options": {}
            }
        }

        # Send the POST request to trigger the backup
        response = requests.post(base_url, json=payload, auth=auth, headers=headers)
        response_data = json.loads(response.text)
        execution_id = response_data["backup"]["execution"]["id"]
        execution_url = f"{self.gs_url}/rest/br/backup/{execution_id}.json"
        # wait for backup to complete
        time.sleep(40)
        response_execution_request = requests.get(execution_url, auth=auth)
        if response_execution_request.status_code == 200:
            try:
                response_execution_json = response_execution_request.json()
                response_status = response_execution_json["backup"]["execution"]["status"]
                self.assertEqual(response_status, 'COMPLETED', "backup initiated successfully")
            except ValueError as e:
                print("Error parsing JSON:", e)
                print("Raw response content:", response_execution_request.text)
        else:
            print(f"Request failed with status code {response_execution_request.status_code}")
            print("Response content:", response_execution_request.text)

        # Verify the response status code
        self.assertEqual(response.status_code, 201, "backup initiated successfully")


if __name__ == "__main__":
    unittest.main()
