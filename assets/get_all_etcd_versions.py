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
when the plugin can install its linux-amd64 archive: the release's SHA256SUMS must
list the archive, or the release must be older than UNVERIFIED_BEFORE, which may
publish no checksum. When GitHub cannot be reached, the script exits with an error
and leaves versions.txt alone, so the workflow shows the failure instead of
quietly keeping an old list.
"""

import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

import requests
from packaging.version import InvalidVersion, Version

TAGS_URL = "https://api.github.com/repos/etcd-io/etcd/tags"
TAGS_FILE = "etcd_versions_from_github_api.json"
VERSIONS_FILE = "versions.txt"
PAGES = 9
PER_PAGE = 100
TIMEOUT_SECONDS = 30
CONCURRENCY = 16
RELEASE_PREFIX = "refs/tags/v"
RELEASE_URL = "https://github.com/etcd-io/etcd/releases/download/v{version}/"
ARCHIVE_NAME = "etcd-v{version}-linux-amd64.tar.gz"
# A release before this version may be installed without a checksum. Keep it in step with UNVERIFIED_BEFORE in
# lib/etcd_utils.lua.
UNVERIFIED_BEFORE = "3.4.0"


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


def listed_in_checksums(text, archive):
    """Reports whether a SHA256SUMS file lists archive."""
    for line in text.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1].lstrip("*") == archive:
            return True
    return False


def can_download(url):
    """Reports whether url serves a file. Only its first byte is requested, so the archive is not fetched."""
    response = requests.get(url, headers={"Range": "bytes=0-0"}, stream=True, timeout=TIMEOUT_SECONDS)
    response.close()
    if response.status_code in (200, 206):
        return True
    if response.status_code == 404:
        return False
    raise SystemExit(f"GitHub returned HTTP {response.status_code} for {url}; versions.txt is unchanged")


def is_installable(version):
    """Reports whether the plugin can install version's linux-amd64 archive.

    The archive is installable when the release's SHA256SUMS lists it. A release older than UNVERIFIED_BEFORE
    is installable without a checksum, so it counts when the archive can be downloaded. A release without a
    SHA256SUMS answers 404; any other failure stops the script, so that a failed request cannot shrink the list.
    """
    archive = ARCHIVE_NAME.format(version=version)
    release_url = RELEASE_URL.format(version=version)
    checksums_url = release_url + "SHA256SUMS"
    response = requests.get(checksums_url, timeout=TIMEOUT_SECONDS)
    if response.status_code not in (200, 404):
        raise SystemExit(f"GitHub returned HTTP {response.status_code} for {checksums_url}; versions.txt is unchanged")
    if response.status_code == 200 and listed_in_checksums(response.text, archive):
        return True
    if Version(version) >= Version(UNVERIFIED_BEFORE):
        return False
    return can_download(release_url + archive)


def main():
    tags = fetch_tags()
    with open(TAGS_FILE, "w", encoding="utf-8") as file:
        json.dump(tags, file, indent=4)

    candidates = release_versions(tags)
    # Each check is a network request, so the checks run side by side. map keeps the newest-first order.
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
        installable = list(pool.map(is_installable, candidates))
    versions = [version for version, keep in zip(candidates, installable, strict=True) if keep]
    if not versions:
        raise SystemExit("no installable etcd release was found; versions.txt is unchanged")
    with open(VERSIONS_FILE, "w", encoding="utf-8", newline="\n") as file:
        for version in versions:
            file.write(version + "\n")
    print(f"wrote {len(versions)} etcd versions to {VERSIONS_FILE}, newest {versions[0]}", file=sys.stderr)


if __name__ == "__main__":
    main()
