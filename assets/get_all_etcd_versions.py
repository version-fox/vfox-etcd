# Copyright 2026 version-fox and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Refreshes versions.txt from the etcd release tags.

Run it from the assets directory, as the update_etcd_versions workflow does. The
tags are saved beside it in etcd_versions_from_github_api.json. A version is kept
only when the plugin can install it, which needs the release's SHA256SUMS to list
the linux-amd64 archive: the plugin does not install an archive without a checksum.
When GitHub cannot be reached, the script exits with an error and leaves
versions.txt alone, so the workflow shows the failure instead of quietly keeping
an old list.
"""

import json
import os
import sys

import requests
from packaging.version import InvalidVersion, Version

TAGS_URL = "https://api.github.com/repos/etcd-io/etcd/tags"
TAGS_FILE = "etcd_versions_from_github_api.json"
VERSIONS_FILE = "versions.txt"
PAGES = 9
PER_PAGE = 100
TIMEOUT_SECONDS = 30
RELEASE_PREFIX = "refs/tags/v"
CHECKSUMS_URL = "https://github.com/etcd-io/etcd/releases/download/v{version}/SHA256SUMS"
ARCHIVE_NAME = "etcd-v{version}-linux-amd64.tar.gz"


def fetch_tags():
    """Returns every tag of the etcd repository, as GitHub's API lists them."""
    headers = {"Accept": "application/vnd.github+json"}
    # An authenticated request has a much higher rate limit than an anonymous one.
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    tags = []
    for page in range(1, PAGES + 1):
        response = requests.get(
            TAGS_URL,
            params={"per_page": PER_PAGE, "sort": "pushed", "page": page},
            headers=headers,
            timeout=TIMEOUT_SECONDS,
        )
        if response.status_code != 200:
            raise SystemExit(f"GitHub API returned HTTP {response.status_code} for page {page} of the etcd tags")
        page_tags = response.json()
        if not page_tags:
            break
        tags.extend(page_tags)
    return tags


def is_release(version):
    """Reports whether a tag name is a version packaging can order."""
    try:
        Version(version)
    except InvalidVersion:
        return False
    return True


def release_versions(tags):
    """Returns the distinct release numbers among the tags, newest first."""
    versions = set()
    for item in tags:
        tarball = item["tarball_url"]
        if RELEASE_PREFIX not in tarball:
            continue
        versions.add(tarball.split(RELEASE_PREFIX, 1)[1])
    return sorted((v for v in versions if is_release(v)), key=Version, reverse=True)


def is_installable(version):
    """Reports whether the plugin can install version: its SHA256SUMS must list the linux-amd64 archive.

    A release without a SHA256SUMS answers 404 and is left out. Any other failure stops the script,
    so that a request which failed cannot shrink the list.
    """
    url = CHECKSUMS_URL.format(version=version)
    response = requests.get(url, timeout=TIMEOUT_SECONDS)
    if response.status_code == 404:
        return False
    if response.status_code != 200:
        raise SystemExit(f"GitHub returned HTTP {response.status_code} for {url}; versions.txt is unchanged")
    archive = ARCHIVE_NAME.format(version=version)
    for line in response.text.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1].lstrip("*") == archive:
            return True
    return False


def main():
    tags = fetch_tags()
    with open(TAGS_FILE, "w", encoding="utf-8") as file:
        json.dump(tags, file, indent=4)

    versions = [version for version in release_versions(tags) if is_installable(version)]
    if not versions:
        raise SystemExit("no installable etcd release was found; versions.txt is unchanged")
    with open(VERSIONS_FILE, "w", encoding="utf-8", newline="\n") as file:
        for version in versions:
            file.write(version + "\n")
    print(f"wrote {len(versions)} etcd versions to {VERSIONS_FILE}, newest {versions[0]}", file=sys.stderr)


if __name__ == "__main__":
    main()
