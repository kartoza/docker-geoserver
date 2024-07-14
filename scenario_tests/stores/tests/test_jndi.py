import unittest
from os import environ

from geo.Geoserver import Geoserver
from requests import get, post, exceptions, delete
from requests.auth import HTTPBasicAuth
from subprocess import check_call


class TestGeoServerJNDI(unittest.TestCase):

    def setUp(self):
        # Define the GeoServer URL
        self.gs_url = 'http://localhost:8080/geoserver'
        # Define the PostGIS JNDI store name
        self.jndi_store_name = 'gis'
        self.geo_username = environ.get('GEOSERVER_ADMIN_USER', 'admin')
        self.geo_password = environ.get('GEOSERVER_ADMIN_PASSWORD', 'myawesomegeoserver')
        self.geo_workspace_name = 'demo'

    def test_publish_jndi_store(self):

        # Import shp into DB
        db_importer = '''ogr2ogr -progress -append -skipfailures -a_srs "EPSG:4326" -nlt PROMOTE_TO_MULTI \
                -f "PostgreSQL" PG:"dbname=gis port=5432 user=docker password=docker host=db" \
                 /usr/local/tomcat/data/data/shapefiles/states.shp '''
        check_call(db_importer, shell=True)

        geo = Geoserver(self.gs_url, username='%s' % self.geo_username, password='%s' % self.geo_password)

        auth = HTTPBasicAuth('%s' % self.geo_username, '%s' % self.geo_password)
        # create workspace
        geo.create_workspace(workspace='%s' % self.geo_workspace_name)
        geo.set_default_workspace('%s' % self.geo_workspace_name)

        # Create the XML payload for the JNDI store configuration
        xml = """
        <dataStore>
          <name>{name}</name>
          <type>PostGIS (JNDI)</type>
          <enabled>true</enabled>
          <connectionParameters>
            <entry key="schema">public</entry>
            <entry key="Estimated extends">true</entry>
            <entry key="fetch size">1000</entry>
            <entry key="encode functions">true</entry>
            <entry key="Expose primary keys">false</entry>
            <entry key="Support on the fly geometry simplification">true</entry>
            <entry key="Batch insert size">1</entry>
            <entry key="preparedStatements">false</entry>
            <entry key="Method used to simplify geometries">FAST</entry>
            <entry key="jndiReferenceName">java:comp/env/jdbc/postgres</entry>
            <entry key="dbtype">postgis</entry>
            <entry key="Loose bbox">true</entry>
          </connectionParameters>
          <disableOnConnFailure>false</disableOnConnFailure>
        </dataStore>
        """.format(name=self.jndi_store_name)

        # Publish the JNDI store
        response = post(self.gs_url + '/rest/workspaces/%s/datastores' % self.geo_workspace_name, auth=auth,
                        headers={'Content-type': 'text/xml'},
                        data=xml)

        # Publish layer into geoserver
        geo.publish_featurestore(workspace='%s'
                                           % self.geo_workspace_name, store_name='%s' % self.jndi_store_name,
                                 pg_table='states')
        # Check that the response has a status code of 201 (Created)
        self.assertEqual(response.status_code, 201)

        # Check that the JNDI store exists
        data_source_url = '%s/rest/workspaces/%s/datastores/%s.json' % (
            self.gs_url, self.geo_workspace_name, self.jndi_store_name)
        response = get(data_source_url, auth=auth)

        # Check that the response has a status code of 200 (OK)
        self.assertEqual(response.status_code, 200)


if __name__ == '__main__':
    unittest.main()
