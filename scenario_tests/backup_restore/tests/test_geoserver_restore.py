import sys
import unittest
import requests
from requests.auth import HTTPBasicAuth
from os import environ, chmod
from os.path import join, exists
import json
import time


class TestGeoServerRestore(unittest.TestCase):

    def setUp(self):
        """Set up the base URL, authentication, and create the zip file."""
        self.gs_url = 'http://localhost:8080/geoserver'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.backup_path = "/settings/backup/"

    def test_restore_backup(self):
        """Test restoring an existing backup of a GeoServer instance using the Backup and Restore plugin."""
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        base_url = f"{self.gs_url}/rest/br/restore/"
        backup_file = join(self.backup_path, 'geoserver.zip')
        chmod(self.backup_path, 0o777)
        if not exists(backup_file):
            sys.exit()

        headers = {
            "Content-Type": "application/json"
        }

        payload = {
            "restore": {
                "archiveFile": backup_file,
                "options": {
                    "option": ["BK_BEST_EFFORT=true"]
                }
            }
        }

        # Send the POST request to trigger the backup
        response = requests.post(base_url, json=payload, auth=auth, headers=headers)
        response_data = json.loads(response.text)
        execution_id = response_data["restore"]["execution"]["id"]
        execution_url = f"{self.gs_url}/rest/br/restore/{execution_id}.json"
        # wait for backup to complete
        time.sleep(30)
        response_execution_request = requests.get(execution_url, auth=auth)
        if response_execution_request.status_code == 200:
            try:
                response_execution_json = response_execution_request.json()
                response_status = response_execution_json["restore"]["execution"]["status"]
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
