# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages list the pull requests.

## Unreleased

- `vfox link --detect etcd` finds the etcd installations that are already on the machine and links them, instead of downloading another copy. It needs vfox 1.1.0 or later. Each one is named after its version and where it was found, such as `3.5.12-system` or `3.5.12-brew`. See [link.md](link.md).
- `BUILD_WITH_FAILPOINT=yes` builds the release tag of the version you install, not the default branch. Earlier releases cloned the default branch, so `vfox install etcd@3.4.32` built a different etcd from the one named. The build puts gofail on `PATH` and sets `FAILPOINTS=true`, without which the binary has no failpoints. It is tested with etcd 3.4.32 and 3.5.12, and etcd 3.6.0 stops with an error. See [failpoint.md](failpoint.md).
- `BUILD_WITH_FAILPOINT=yes` on Windows prints a notice and installs the official build. Before, it was ignored without a word.
- An archive whose checksum is missing from the release's `SHA256SUMS` is no longer installed without verification. The install stops and names the file. See [troubleshooting.md](troubleshooting.md).
- A version that is not a release, such as `3.5` or `3.5.12; rm`, is refused before anything is downloaded.
- `vfox use` of a version that is not installed says how to install it, instead of failing with a Lua error.
- A failed download of the version list or of `SHA256SUMS` stops with the URL and the HTTP status. Before, the install went on without a checksum, and a failed version list was a Lua error.
- The plugin description and the docs name `etcdutl`, where they said `etcductl`.

For maintainers:

- Lint, offline plugin tests, license headers, documentation pairs and end-to-end suites on Ubuntu, macOS and Windows. The Chinese pages are checked against the English ones.
- `.github/workflows/e2e_test.yaml` is replaced by `.github/workflows/e2e.yml`.
- The version updater fails when GitHub cannot be reached. Before, it kept the old list and exited successfully. It also sends a token when one is set.

## 0.2.0 (2024-05-19)

- Builds etcd with failpoints, with `BUILD_WITH_FAILPOINT=yes`.
- Checks the downloaded archive against the SHA-256 that etcd publishes.
- `vfox use` works for a version that was built with failpoints.
- `vfox search etcd` lists the versions newest first, and fetches more of them.
- The README has a badge and a logo.
