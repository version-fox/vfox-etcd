# End-to-end tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

The end-to-end suites install vfox, add the plugin from a ZIP made of this checkout, and drive the plugin the way a user does. They live in `tests/e2e`, one Go package per platform, and use only the Go standard library.

## The suites

| Package | Runs on | What it proves |
| --- | --- | --- |
| `unix` | Ubuntu and macOS, on the host | An archive install with `etcd`, `etcdctl` and `etcdutl` on `PATH`; a system etcd adopted with `vfox link --detect etcd` and used; a failpoint build of etcd 3.5.12, whose gofail endpoint lists failpoints. |
| `linux` | A bare Ubuntu 24.04 container, built from `tests/e2e/linux/Dockerfile` | An archive install needs no build packages; a system etcd is detected and used inside the container. |
| `windows` | Windows, on the host, with PowerShell | An archive install with the three commands on `PATH`; a system etcd adopted with `vfox link --detect etcd` and used. |

Each suite installs vfox 1.1.0 from the release archive, and checks the archive against the SHA-256 pinned in the Go source. A new vfox release changes `VfoxVersion` and its checksums in `tests/e2e/common/common.go`, the `VFOX_VERSION` and `VFOX_SHA256` arguments of `tests/e2e/linux/Dockerfile`, and the same two values in `.github/workflows/test.yml`.

The system installation is simulated: the suite copies the etcd binaries into a directory of its own and puts that directory on `PATH` before it runs `vfox link --detect etcd -y`. The name it expects is `<version>-path`, or `-opt` for `/opt`, as the location decides.

Every script activates vfox before it selects a version, because `vfox use` refuses to run without the hook: `eval "$(vfox activate bash)"` in Bash, and `Invoke-Expression "$(vfox activate pwsh)"` in PowerShell.

## Running them

```bash
cd tests/e2e

# unit tests of the helpers; no network, no Docker
go test -short ./...

# the native suite on this host; downloads vfox and etcd, and builds a failpoint etcd
go test -v -timeout 60m ./unix

# the container suite; builds the image and needs Docker
go test -v -timeout 40m -run TestContainerE2E ./linux

# the Windows suite, on a Windows host
go test -v -timeout 60m ./windows
```

The failpoint build needs Git, Go and GNU Make, and takes several minutes. `go test -run 'TestNativeE2E/(archive|system)' ./unix` runs the faster scenarios alone.

The suites set `HOME` and `USERPROFILE` to a temporary directory, so they do not touch your vfox installations. They keep your Go build cache and module cache, so a failpoint build does not compile from nothing, and they put the gofail binary in the temporary directory. The failpoint scenario has a vfox home of its own, because the archive install already holds etcd 3.5.12.

## In CI

The `e2e.yml` workflow runs four jobs: the `unix` suite on `ubuntu-latest` and on `macos-latest`, the container suite on `ubuntu-latest`, and the `windows` suite on `windows-latest`. A push to a pull request replaces the run before it.
