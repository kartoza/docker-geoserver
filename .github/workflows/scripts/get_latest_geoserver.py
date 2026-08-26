import re
import requests
from bs4 import BeautifulSoup
import sys
from pathlib import Path

FALLBACK_GEOSERVER_VERSION = "2.28.5"


def get_latest_geoserver_version():
    url = "https://geoserver.org/release/maintain/"

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
    try:
        version = get_latest_geoserver_version()
        major, minor, bugfix = version.split(".")
        if not all(part.isdigit() for part in (major, minor, bugfix)):
            raise ValueError(f"invalid version: {version}")
    except (requests.RequestException, ValueError, AttributeError, TypeError) as error:
        print(
            f"Could not determine the latest GeoServer version ({error}); "
            f"using Dockerfile fallback: {FALLBACK_GEOSERVER_VERSION}"
        )
        version = FALLBACK_GEOSERVER_VERSION
        major, minor, bugfix = version.split(".")

    print(f"GeoServer version: {version}")

    github_output = Path("/github_output/github_output.txt")

    with github_output.open("a") as f:
        f.write(f"version={version}\n")
        f.write(f"major={major}\n")
        f.write(f"minor={minor}\n")
        f.write(f"bugfix={bugfix}\n")


if __name__ == "__main__":
    main()
