import re
import requests
from pathlib import Path

TOMCAT_REPO = "library/tomcat"
FALLBACK_TOMCAT_TAG = "9.0.121-jdk17-temurin-noble"
TAG_PATTERN = re.compile(
    r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)-jdk17-temurin-noble$"
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
    url = "https://hub.docker.com/v2/repositories/library/tomcat/tags?page_size=100&name=9."

    latest_tag = None
    latest_version = None

    while url:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()

        for result in data["results"]:
            tag = result["name"]

            if not tag.startswith("9."):
                continue

            # optional stricter filter
            if "-jdk17-temurin-noble" not in tag:
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
    try:
        tag, version = get_latest_tomcat_tag()
    except (requests.RequestException, ValueError, KeyError, TypeError) as error:
        print(
            f"Could not determine the latest Tomcat version ({error}); "
            f"using Dockerfile fallback: {FALLBACK_TOMCAT_TAG}"
        )
        tag, version = FALLBACK_TOMCAT_TAG, version_key(FALLBACK_TOMCAT_TAG)

    if not tag or not version:
        print(
            "Could not parse a supported Tomcat version; "
            f"using Dockerfile fallback: {FALLBACK_TOMCAT_TAG}"
        )
        tag = FALLBACK_TOMCAT_TAG

    print(f"Tomcat version: {tag}")
    github_output = Path("/github_output/github_output.txt")

    with github_output.open("a") as f:
        f.write(f"tomcat_version={tag}\n")

if __name__ == "__main__":
    main()
