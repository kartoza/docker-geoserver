import os
import tempfile
import unittest

import requests


class TestArbitraryUID(unittest.TestCase):
    def test_process_uses_requested_arbitrary_uid_and_root_group(self):
        self.assertEqual(os.getuid(), 12345)
        self.assertEqual(os.getgid(), 0)

    def test_runtime_directories_are_writable(self):
        paths = (
            "/opt/geoserver/data_dir",
            "/opt/geoserver/data_dir/gwc",
            "/settings",
            "/usr/local/tomcat/conf",
            "/usr/local/tomcat/logs",
            "/usr/local/tomcat/temp",
            "/usr/local/tomcat/work",
        )

        for path in paths:
            with self.subTest(path=path):
                with tempfile.NamedTemporaryFile(dir=path):
                    pass

    def test_geoserver_rest_api_is_available(self):
        response = requests.get(
            "http://localhost:8080/geoserver/rest/about/version.json",
            auth=("admin", "myawesomegeoserver"),
            timeout=30,
        )
        self.assertEqual(response.status_code, 200)


if __name__ == "__main__":
    unittest.main()
