# Usage: python3 stable_plugins.py 2.23.0 https://sourceforge.net/projects/geoserver/files/GeoServer
#        python3 stable_plugins.py version GeoServer_Base_URL
import requests
from bs4 import BeautifulSoup

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("version", help="GeoServer version number, e.g. 2.23.0")
parser.add_argument("base_url",
                    help="Base URL to download GeoServer extensions i.e, e.g."
                         " https://sourceforge.net/projects/geoserver/files/GeoServer")
args = parser.parse_args()

url = '%s/%s/extensions' % (args.base_url, args.version)
print(url)
response = requests.get(url)
soup = BeautifulSoup(response.content, 'html.parser')

plugin_list = []
for link in soup.find_all('a'):
    href = link.get('href')

    if href is not None:
        if href.endswith('/download') and href.startswith('https'):
            plugin_base = href.replace("%s/" % url, "")
            plugin_name = plugin_base.replace('.zip/download', '')
            plugin_base_name = plugin_name.replace("geoserver-%s-" % args.version, "")
            plugin_list.append(plugin_base_name)

required_plugins = set()
with open('required_plugins.txt', 'r') as f:
    for plugin in f:
        plugin = plugin.strip()
        if plugin:
            required_plugins.add(plugin)

with open('stable_plugins.txt', 'w') as f:
    for plugin in plugin_list:
        if plugin not in required_plugins:
            f.write(plugin + '\n')
