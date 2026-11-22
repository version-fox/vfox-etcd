# etcd with failpoints

[中文](zh-CN/failpoint.md) | [English](failpoint.md)

[Failpoints](https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally) let a test make etcd fail at a chosen point, which the robustness tests use for chaos testing. They are compiled in by [gofail](https://github.com/etcd-io/gofail). The official archives have none, so the plugin builds etcd from source when you ask for it:

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

The plugin has been tested with etcd 3.4.32 and 3.5.12. The 3.6.0 release has no gofail targets in its Makefile, so a build of it stops with an error.

## What the build does

With `BUILD_WITH_FAILPOINT=yes`, the plugin skips the archive download. After vfox has created the install directory, it runs these commands in it:

```bash
git clone --depth 1 --branch v3.5.12 https://github.com/etcd-io/etcd.git etcd
cd etcd
export PATH="$(go env GOBIN | grep . || echo "$(go env GOPATH | cut -d: -f1)/bin"):$PATH"
make install-gofail
FAILPOINTS=true make build
```

The clone is the tag of the version you asked for. Plugin releases before 0.2.1 cloned the default branch, which built a different etcd than the one named.

gofail has to be on the `PATH` before the make targets run. `go install` puts it in `GOBIN`, or else in the first entry of `GOPATH`, so the command adds that directory to the `PATH` first. The build then runs with `FAILPOINTS=true`, because etcd's build script enables the failpoints only when it is set. A build that has them reports `-FAILPOINTS` in its Git SHA, which `etcd --version` prints.

The 3.4 line has a `gofail-enable` target, which enables the failpoints itself. For those releases the plugin runs `make gofail-enable` in place of `make install-gofail`.

The binaries end up in `etcd/bin` inside the install directory, and the plugin puts that directory on the `PATH` when the version is selected.

## What it needs

- Linux or macOS. On Windows, `BUILD_WITH_FAILPOINT` prints a notice and the official build is installed.
- Git, to clone etcd.
- Go, at the version the etcd release asks for, on the `PATH` when `vfox install` runs.
- GNU Make.

A build takes several minutes. Its output is printed, so a failure shows the command that failed.

## Use it

```bash
vfox use -g etcd@3.5.12

# start etcd with failpoints enabled
GOFAIL_HTTP="127.0.0.1:22381" etcd

# list the failpoints that were compiled in
curl http://127.0.0.1:22381
```

## After a failed build

A build that fails part way can leave a partial clone in the install directory, and the next `git clone` then refuses to write into it. Remove the version and install it again:

```bash
vfox uninstall etcd@3.5.12
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```
