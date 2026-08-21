# Usage python3 community_plugins.py 2.23.x
import requests
from bs4 import BeautifulSoup
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("version", help="GeoServer version number, e.g. 2.23.x")
parser.add_argument(
    "base_url",
    nargs="?",
    help="Direct URL of the community-latest directory",
)
parser.add_argument(
    "snapshot_version",
    nargs="?",
    help="Version used in community plugin snapshot filenames, e.g. 3.0.0",
)
args = parser.parse_args()

url = args.base_url or (
    "https://build.geoserver.org/geoserver/%s/community-latest/" % args.version
)
url = url.rstrip("/") + "/"

try:
    response = requests.get(url, timeout=(10, 30))
    response.raise_for_status()
except requests.RequestException as error:
    reason = " ".join(str(error).splitlines())
    with open("community_plugin_discovery_failure.txt", "w") as failure_file:
        failure_file.write("__discovery__\t%s\n" % reason)
    open("community_plugins.txt", "w").close()
    print(
        "Community plugin discovery failed; no community plugins will be bundled: %s" % reason,
        file=sys.stderr,
    )
    sys.exit(0)

soup = BeautifulSoup(response.content, "html.parser")

plugin_list = []
for link in soup.find_all("a"):
    href = link.get("href")
    if href and href.endswith(".zip"):
        plugin_list.append(href.split("/")[-1])

if not plugin_list:
    reason = "community plugin index contained no ZIP links"
    with open("community_plugin_discovery_failure.txt", "w") as failure_file:
        failure_file.write("__discovery__\t%s\n" % reason)
    open("community_plugins.txt", "w").close()
    print(
        "Community plugin discovery failed; no community plugins will be bundled: %s" % reason,
        file=sys.stderr,
    )
    sys.exit(0)

with open('community_plugins.txt.tmp', 'w') as f:
    for plugin in plugin_list:
        _version = args.snapshot_version or args.version.replace(".x", ".0")
        sub_string = "geoserver-%s-SNAPSHOT-" % _version
        plugin_file = plugin.replace("%s" % sub_string, "")
        plugin_name = plugin_file.replace(".zip", "")
        f.write(plugin_name + '\n')

with open('community_plugins.txt.tmp', 'r') as source:
    contents = source.read()
with open('community_plugins.txt', 'w') as destination:
    destination.write(contents)
