import unittest
from os import environ

from geo.Geoserver import Geoserver
from requests import get, post, exceptions
from requests.auth import HTTPBasicAuth
from shutil import copy


class GeoServerClusteringMaster(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        # Define the PostGIS JNDI store name
        self.store_name = 'gis'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.geo_workspace_name = 'demo'

    def test_publish_store(self):
        geo = Geoserver(self.gs_url, username='%s' % self.geo_username, password='%s' % self.geo_password)
        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        # create workspace
        geo.create_workspace(workspace='%s' % self.geo_workspace_name)
        geo.set_default_workspace('%s' % self.geo_workspace_name)

        # Create the XML payload for the JNDI store configuration
        xml = """
        <dataStore>
          <name>{name}</name>
          <type>PostGIS</type>
          <enabled>true</enabled>
          <connectionParameters>
            <entry key="host">db</entry>
            <entry key="port">5432</entry>
            <entry key="database">gis</entry>
            <entry key="user">docker</entry>
            <entry key="passwd">docker</entry>
            <entry key="schema">public</entry>
            <entry key="Estimated extends">true</entry>
            <entry key="fetch size">1000</entry>
            <entry key="encode functions">true</entry>
            <entry key="Expose primary keys">false</entry>
            <entry key="Support on the fly geometry simplification">true</entry>
            <entry key="Batch insert size">1</entry>
            <entry key="preparedStatements">false</entry>
            <entry key="Method used to simplify geometries">FAST</entry>
            <entry key="dbtype">postgis</entry>
            <entry key="Loose bbox">true</entry>
            <entry key="SSL mode">ALLOW</entry>
          </connectionParameters>
          <disableOnConnFailure>false</disableOnConnFailure>
        </dataStore>
        """.format(name=self.store_name)

        # Publish the store
        response = post(self.gs_url + '/rest/workspaces/%s/datastores' % self.geo_workspace_name, auth=auth,
                        headers={'Content-type': 'text/xml'},
                        data=xml)

        # Check that the response has a status code of 201 (Created)
        self.assertEqual(response.status_code, 201)

        # Check that the store exists
        data_source_url = '%s/rest/workspaces/%s/datastores/%s.json' % (
            self.gs_url, self.geo_workspace_name, self.store_name)
        response = get(data_source_url, auth=auth)

        # Check that the response has a status code of 200 (OK)
        self.assertEqual(response.status_code, 200)

        # Publish layer into GeoServer
        geo.publish_featurestore(workspace='%s'
                                           % self.geo_workspace_name, store_name='%s' % self.store_name,
                                 pg_table='states')
        copy("/usr/local/tomcat/data/styles/default_point.sld", "/usr/local/tomcat/data/styles/states.sld")
        layer_sld_file = "/usr/local/tomcat/data/styles/states.sld"
        geo.upload_style(path=str(layer_sld_file), workspace=self.geo_workspace_name)
        geo.publish_style(layer_name='states', style_name='states', workspace=self.geo_workspace_name)
        self.assertEqual(response.status_code, 200)

        # Check that the layer exists
        layer_url = '%s/rest/workspaces/%s/layers/states.json' % (
            self.gs_url, self.geo_workspace_name)
        response = get(layer_url, auth=auth)

        # Check that the response has a status code of 200 (OK)
        self.assertEqual(response.status_code, 200)


if __name__ == '__main__':
    unittest.main()
