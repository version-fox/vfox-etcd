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

"""Pins the SHA-256 of the archives of the old etcd releases that SHA256SUMS does not list.

The plugin checks each archive against the SHA256SUMS of its release. The releases before CHECKSUMS_FROM mostly
publish none, or one that leaves out some archives. For every listed old release, this script downloads each archive
of the supported platforms that the release's SHA256SUMS does not list, and writes the SHA-256 of each download to
lib/pinned_checksums.lua. The plugin checks those archives against the pinned values.

A pinned value is the hash of the archive as GitHub served it when this script ran. GitHub publishes no digest for
these assets, so nothing independent confirms the values: they guard against an archive that changes afterwards.
The downloads add up to several gigabytes, so the script keeps its progress in WORK_DIR and skips what it already
has; an interrupted run resumes where it stopped. Run it from anywhere:

    python3 assets/pin_old_checksums.py
"""

import hashlib
import json
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from get_all_etcd_versions import CHECKSUMS_FROM, RELEASE_URL, checksum_names
from packaging.version import Version
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

ASSETS = Path(__file__).resolve().parent
VERSIONS_FILE = ASSETS / "versions.txt"
OUTPUT_FILE = ASSETS.parent / "lib" / "pinned_checksums.lua"
WORK_DIR = Path(tempfile.gettempdir()) / "vfox-etcd-pins"
WORKERS = 8
# The platforms the plugin supports, as vfox reports them: operating system, CPU and archive extension.
PLATFORMS = (
    ("linux", "amd64", "tar.gz"),
    ("linux", "arm64", "tar.gz"),
    ("linux", "ppc64le", "tar.gz"),
    ("linux", "s390x", "tar.gz"),
    ("darwin", "amd64", "zip"),
    ("darwin", "arm64", "zip"),
    ("windows", "amd64", "zip"),
)
# The first bytes of each archive kind, so that an error page is never pinned.
MAGIC = {"tar.gz": b"\x1f\x8b", "zip": b"PK\x03\x04"}
LUA_HEADER = """\
-- Copyright 2026 version-fox and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- SHA-256 of the archives of the releases before 3.4.0 that SHA256SUMS does not list, by version and archive name.
-- assets/pin_old_checksums.py writes this file from the archives GitHub serves. Regenerate it with that script
-- rather than editing it by hand.
"""


def archive_name(version, os_type, arch, ext):
    """Returns the name of the archive etcd publishes for one platform of a release."""
    return f"etcd-v{version}-{os_type}-{arch}.{ext}"


def old_versions():
    """Returns the listed releases older than CHECKSUMS_FROM, oldest first."""
    lines = VERSIONS_FILE.read_text(encoding="utf-8").splitlines()
    versions = [line.strip() for line in lines if line.strip()]
    return sorted((v for v in versions if Version(v) < Version(CHECKSUMS_FROM)), key=Version)


def make_session():
    """Returns an HTTP session that retries the failures GitHub signals as temporary."""
    session = requests.Session()
    retry = Retry(total=5, backoff_factor=2, status_forcelist=(429, 500, 502, 503, 504))
    session.mount("https://", HTTPAdapter(max_retries=retry, pool_maxsize=WORKERS))
    return session


def published_names(session, version):
    """Returns the archive names that the release's SHA256SUMS lists. It is empty when there is no SHA256SUMS."""
    url = RELEASE_URL.format(version=version) + "SHA256SUMS"
    response = session.get(url, timeout=60)
    if response.status_code == 404:
        return set()
    if response.status_code != 200:
        raise SystemExit(f"GitHub returned HTTP {response.status_code} for {url}")
    return checksum_names(response.text)


def download(session, version, name, ext):
    """Downloads one archive and returns its SHA-256, or marks it absent when GitHub has no such archive."""
    url = RELEASE_URL.format(version=version) + name
    with session.get(url, stream=True, timeout=(30, 600)) as response:
        if response.status_code == 404:
            return {"version": version, "archive": name, "absent": True}
        if response.status_code != 200:
            raise SystemExit(f"GitHub returned HTTP {response.status_code} for {url}")
        digest = hashlib.sha256()
        size = 0
        head = b""
        for chunk in response.iter_content(chunk_size=1 << 20):
            if len(head) < len(MAGIC[ext]):
                head = (head + chunk)[: len(MAGIC[ext])]
            digest.update(chunk)
            size += len(chunk)
        declared = response.headers.get("Content-Length")
        encoded = response.headers.get("Content-Encoding", "identity") != "identity"
    if not head.startswith(MAGIC[ext]):
        raise SystemExit(f"{url} is not a {ext} archive")
    if declared is not None and not encoded and int(declared) != size:
        raise SystemExit(f"{url}: read {size} bytes, Content-Length says {declared}")
    return {"version": version, "archive": name, "sha256": digest.hexdigest(), "bytes": size}


def load_results():
    """Returns the downloads of earlier runs, keyed by version and archive name."""
    results = {}
    path = WORK_DIR / "results.jsonl"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue  # a run that was stopped mid-write leaves a partial last line
            results[(entry["version"], entry["archive"])] = entry
    return results


def write_lua(versions, published, results):
    """Writes the pinned SHA-256 values to lib/pinned_checksums.lua."""
    pins = {}
    for version in versions:
        for os_type, arch, ext in PLATFORMS:
            name = archive_name(version, os_type, arch, ext)
            entry = results.get((version, name))
            if name not in published[version] and entry is not None and "sha256" in entry:
                pins.setdefault(version, {})[name] = entry
    for version in versions:
        linux = archive_name(version, "linux", "amd64", "tar.gz")
        if linux not in published[version] and linux not in pins.get(version, {}):
            raise SystemExit(f"{linux} is neither in SHA256SUMS nor downloadable")
    lines = [LUA_HEADER.rstrip("\n"), "", "return {"]
    total = 0
    for version in sorted(pins, key=Version, reverse=True):
        lines.append(f'    ["{version}"] = {{')
        for os_type, arch, ext in PLATFORMS:
            name = archive_name(version, os_type, arch, ext)
            if name in pins[version]:
                entry = pins[version][name]
                total += entry["bytes"]
                lines.append(f'        ["{name}"] = "{entry["sha256"]}",')
        lines.append("    },")
    lines.append("}")
    OUTPUT_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    count = sum(len(archives) for archives in pins.values())
    print(f"pinned {count} archives of {len(pins)} releases ({total / 1e6:.0f} MB) in {OUTPUT_FILE}", file=sys.stderr)


def main():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    session = make_session()
    versions = old_versions()
    published = {version: published_names(session, version) for version in versions}
    results = load_results()
    jobs = []
    for version in versions:
        for os_type, arch, ext in PLATFORMS:
            name = archive_name(version, os_type, arch, ext)
            if name not in published[version] and (version, name) not in results:
                jobs.append((version, name, ext))
    print(f"{len(versions)} releases, {len(jobs)} archives to download", file=sys.stderr)
    with open(WORK_DIR / "results.jsonl", "a", encoding="utf-8") as log:
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            futures = [pool.submit(download, session, *job) for job in jobs]
            try:
                for done, future in enumerate(as_completed(futures), 1):
                    entry = future.result()
                    results[(entry["version"], entry["archive"])] = entry
                    log.write(json.dumps(entry) + "\n")
                    log.flush()
                    if done % 25 == 0 or done == len(futures):
                        print(f"  {done}/{len(futures)} downloads finished", file=sys.stderr)
            except BaseException:
                for future in futures:
                    future.cancel()
                raise
    write_lua(versions, published, results)


if __name__ == "__main__":
    main()
