# Platforms

[中文](zh-CN/platforms.md) | [English](platforms.md)

The plugin installs the archive that etcd publishes for your platform. Which archives exist depends on the release. A release lists its archives in `SHA256SUMS`. Releases before 3.4.0 mostly publish none, so the plugin checks their archives against checksums it pins, see [troubleshooting.md](troubleshooting.md).

| Operating system | CPU | Archive | Notes |
| --- | --- | --- | --- |
| Linux | amd64, arm64, ppc64le, s390x | `.tar.gz` | The archive needs no packages. A failpoint build needs Git, Go and GNU Make. |
| macOS | amd64, arm64 | `.zip` | The arm64 archive starts with 3.5.5; 3.4.32 has only amd64. |
| Windows | amd64 | `.zip` | No arm64 archive is published, so an install on arm64 stops with a message. `BUILD_WITH_FAILPOINT` is not supported, the official build is installed instead. |

The CPUs in the table are the ones etcd 3.5.12 publishes archives for. The plugin asks for the archive named after the CPU that vfox reports, so an archive that etcd publishes is installed the same way on any of them.

The CI runs the end-to-end suites on Ubuntu (amd64), macOS and Windows (amd64). See [e2e.md](e2e.md).

## Checking a release

To see which archives a release has, read its checksum file:

```bash
curl -fsSL https://github.com/etcd-io/etcd/releases/download/v3.5.12/SHA256SUMS
```

If the archive for your platform is missing, pick another release, or build etcd from source with [failpoints](failpoint.md), which works on Linux and macOS.
