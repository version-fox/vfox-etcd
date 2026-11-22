# etcd with failpoints

[中文](zh-CN/failpoint.md) | [English](failpoint.md)

[Failpoints](https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally) let a test make etcd fail at a chosen point, which the robustness tests use for chaos testing. They are compiled in by [gofail](https://github.com/etcd-io/gofail). The official archives have none, so the plugin builds etcd from source when you ask for it:

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

The plugin has been tested with etcd 3.4.32, 3.5.12 and 3.6.0. Only the exact value `yes` turns the build on: any other value, such as `1`, stops the install with an error, and an unset or empty variable installs the official build.

## What the build does

With `BUILD_WITH_FAILPOINT=yes`, the plugin skips the archive download. After vfox has created the install directory, it runs these commands in it:

```bash
git clone --depth 1 --branch v3.5.12 https://github.com/etcd-io/etcd.git etcd
cd etcd
export PATH="$(go env GOBIN | grep . || echo "$(go env GOPATH | cut -d: -f1)/bin"):$PATH"
make install-gofail
# where the release has a gofail-enable target, make gofail-enable runs instead
FAILPOINTS=true make build
```

The clone is the tag of the version you asked for. Plugin releases before 0.2.1 cloned the default branch, which built a different etcd than the one named.

gofail has to be on the `PATH` before the make targets run. `go install` puts it in `GOBIN`, or else in the first entry of `GOPATH`, so the command adds that directory to the `PATH` first. For 3.4 and 3.5 the build runs with `FAILPOINTS=true`, because etcd's build script enables the failpoints only when it is set. A 3.4 or 3.5 build with failpoints reports `-FAILPOINTS` in its Git SHA, which `etcd --version` prints. The 3.6 build does not add that suffix, so the plugin checks the binary instead: it must link the gofail runtime, or the install stops with an error.

Some releases have a `gofail-enable` target, which enables the failpoints itself: 3.4 has it in its root Makefile, and 3.6 in a makefile that the root one includes. For those releases the plugin runs `make gofail-enable` in place of `make install-gofail`, and it finds the target wherever it is defined.

The binaries end up in `etcd/bin` inside the install directory, and the plugin puts that directory on the `PATH` when the version is selected.

## What it needs

- Linux or macOS. On Windows, `BUILD_WITH_FAILPOINT` prints a notice and the official build is installed.
- Git, to clone etcd.
- Go, at the version the etcd release asks for, on the `PATH` when `vfox install` runs.
- GNU Make.

The plugin checks for these programs before it clones etcd, and names any that is missing. A build takes several minutes. Its output is printed, so a failure shows the command that failed.

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
