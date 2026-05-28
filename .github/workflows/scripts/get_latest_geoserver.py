import re
import requests
from bs4 import BeautifulSoup
import sys
from pathlib import Path


def get_latest_geoserver_version():
    url = "https://geoserver.org/release/stable/"

    response = requests.get(url, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")

    text = soup.get_text(" ", strip=True)

    versions = re.findall(r"\b\d+\.\d+(?:\.\d+)?\b", text)

    if not versions:
        return None

    def version_key(v):
        return tuple(map(int, v.split(".")))

    return sorted(set(versions), key=version_key, reverse=True)[0]


def main():
    version = get_latest_geoserver_version()

    if not version:
        print("Could not determine GeoServer version.")
        sys.exit(1)

    major, minor, bugfix = version.split(".")

    print(f"Latest GeoServer stable version: {version}")

    github_output = Path("/github_output/github_output.txt")

    with github_output.open("a") as f:
        f.write(f"version={version}\n")
        f.write(f"major={major}\n")
        f.write(f"minor={minor}\n")
        f.write(f"bugfix={bugfix}\n")


if __name__ == "__main__":
    main()