import re
import requests
from pathlib import Path


TOMCAT_REPO = "library/tomcat"
TAG_PATTERN = re.compile(
    r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)-jdk21-temurin-noble$"
)

#TODO Update when GeoServer 3 is out which uses the tomcat 10 seies
def version_key(v):
    match = re.match(r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)-.*$", v)
    if not match:
        return None

    return (
        int(match.group("major")),
        int(match.group("minor")),
        int(match.group("patch")),
    )



def get_latest_tomcat_tag():
    url = "https://hub.docker.com/v2/repositories/library/tomcat/tags?page_size=100&name=11."

    latest_tag = None
    latest_version = None

    while url:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()

        for result in data["results"]:
            tag = result["name"]

            if not tag.startswith("11."):
                continue

            # optional stricter filter
            if "-jdk21-temurin-noble" not in tag:
                continue

            parsed = version_key(tag)
            if not parsed:
                continue

            if latest_version is None or parsed > latest_version:
                latest_version = parsed
                latest_tag = tag

        url = data.get("next")

    return latest_tag, latest_version

def main():
    tag, version = get_latest_tomcat_tag()

    if version:
        print(f"Latest tomcat version in the 11 Series: {tag}")
        github_output = Path("/github_output/github_output.txt")

        with github_output.open("a") as f:
            f.write(f"tomcat_version={tag}\n")

if __name__ == "__main__":
    main()

