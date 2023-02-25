import unittest
import requests


class PostgisJNDIGeoServer(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        # Define the PostGIS JNDI store name
        self.jndi_store_name = 'demo'

    def publish_jndi_store(self):
        # Set up the authentication credentials
        auth = ('admin', 'myawesomegeoserver')

        # Create the XML payload for the JNDI store configuration
        xml = """
        <dataStore>
          <name>{name}</name>
          <connectionParameters>
            <entry key="host">localhost</entry>
            <entry key="port">5432</entry>
            <entry key="database">gis</entry>
            <entry key="user">docker</entry>
            <entry key="passwd">docker</entry>
            <entry key="dbtype">postgis</entry>
          </connectionParameters>
          <enabled>true</enabled>
          <type>PostGIS (JNDI)</type>
          <JDBC>
            <JNDIName>jdbc/my_postgis_datasource</JNDIName>
          </JDBC>
        </dataStore>
        """.format(name=self.jndi_store_name)

        # Publish the JNDI store
        response = requests.post(self.gs_url + '/rest/workspaces/myworkspace/datastores',
                                 auth=auth,
                                 headers={'Content-type': 'text/xml'},
                                 data=xml)

        # Check that the response has a status code of 201 (Created)
        self.assertEqual(response.status_code, 201)

        # Check that the JNDI store exists
        response = requests.get(self.gs_url + '/rest/workspaces/myworkspace/datastores/' + self.jndi_store_name,
                                auth=auth)

        # Check that the response has a status code of 200 (OK)
        self.assertEqual(response.status_code, 200)

    def tearDown(self):
        # Delete the JNDI store
        requests.delete(self.gs_url + '/rest/workspaces/myworkspace/datastores/' + self.jndi_store_name,
                        auth=('admin', 'geoserver'))


if __name__ == '__main__':
    unittest.main()
