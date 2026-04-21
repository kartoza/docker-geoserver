# Usage python3 community_plugins.py 2.23.x
import requests
from bs4 import BeautifulSoup
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("version", help="GeoServer version number, e.g. 2.23.x")
args = parser.parse_args()

url = "https://build.geoserver.org/geoserver/%s/community-latest/" % args.version


response = requests.get(url)
soup = BeautifulSoup(response.content, "html.parser")

plugin_list = []
for link in soup.find_all("a"):
    href = link.get("href")
    if href and href.endswith(".zip"):
        plugin_list.append(href.split("/")[-1])

with open('community_plugins.txt', 'w') as f:
    for plugin in plugin_list:
        _version = args.version.replace(".x", "")
        sub_string = "geoserver-%s-SNAPSHOT-" % _version
        plugin_file = plugin.replace("%s" % sub_string, "")
        plugin_name = plugin_file.replace(".zip", "")
        f.write(plugin_name + '\n')
