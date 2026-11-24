# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

The messages below come from the plugin, or from vfox while it runs the plugin's hooks.

When the plugin refuses an install, it prints its message without a stack traceback, and vfox then reports `no installable runtime provided`. An error that the plugin raises, such as a failed download, still comes with a stack traceback.

## `invalid etcd version 3.5`

The plugin needs a full release, such as `3.5.12`. Partial versions are refused, because they do not name one download:

```bash
vfox search etcd
vfox install etcd@3.5.12
```

## `there is no etcd release 9.9.9, see https://github.com/etcd-io/etcd/releases for the releases that exist`

The version is a full release number, but GitHub has no etcd release with that name. The plugin stops before it downloads an archive, a checksum or the source. Check the spelling, and pick a release from the list:

```bash
vfox search etcd
vfox install etcd@3.5.12
```

`vfox search etcd` lists the releases that install on Linux amd64, so pick one from that list.

## `etcd 3.7.4 has no Windows arm64 build, see https://github.com/etcd-io/etcd/releases/tag/v3.7.4 for the archives it has`

The release has no archive for your platform, so the install stops before the archive is downloaded. The message is printed without a stack traceback. vfox then reports `no installable runtime provided`, which is what it reports when a plugin returns no result from `PreInstall`. Pick a release that has an archive for your platform, or read [platforms.md](platforms.md). etcd has published no arm64 archive for Windows in any release, so on Windows arm64 this is the message to expect. For example, 3.4.32 has no Apple silicon archive, and the arm64 archive for macOS starts with 3.5.5.

## `could not download https://github.com/etcd-io/etcd/releases/download/v3.5.0-alpha.0/SHA256SUMS: HTTP 404`

The release publishes no `SHA256SUMS`, and it is 3.4.0 or later. The plugin does not install an archive from such a release without a checksum, so the install stops. Pick a release from `vfox search etcd`: the list leaves out the releases from 3.4.0 on that publish no checksum. Releases before 3.4.0 are checked against pinned checksums instead, see the next section.

## `etcd 0.4.9 publishes no checksum for ..., so the archive is checked against the SHA-256 pinned in this plugin.`

The release is before 3.4.0, and its `SHA256SUMS` has no entry for the archive, or no file at all. The plugin checks the archive against the SHA-256 that it pins for it, and prints this line before the install. The pinned values were taken from the archives GitHub served when the plugin was pinned, so the check guards against a change after that, not against a bad download at that time.

## `etcd 3.3.13 has no Windows arm64 build that the plugin has a checksum for, see https://github.com/etcd-io/etcd/releases/tag/v3.3.13 for the archives it has`

The release is older than 3.4.0. Its `SHA256SUMS` may be missing, or may not list the archive for your platform, and the plugin pins no checksum for that archive. The plugin does not install an archive that it cannot check, so the install stops before the archive is downloaded, and no stack traceback follows the message. The message does not say that the release has no build, because the plugin knows only the archives it pins. Pick another release, or see [platforms.md](platforms.md).

## `could not download https://...`

The plugin could not reach GitHub, or GitHub answered with an error that is shown with its HTTP status. Check your network and any proxy settings, then run the command again. The version list comes from jsDelivr, so `vfox search etcd` can fail on the same network problem.

## `BUILD_WITH_FAILPOINT is only supported on Linux and macOS, installing the official Windows build.`

On Windows the official build is installed, and the plugin prints this notice. Remove the variable from the environment to stop the notice. See [failpoint.md](failpoint.md) for what the Linux and macOS build needs.

## `BUILD_WITH_FAILPOINT is "1", but only yes turns on the failpoint build. Unset it to install the official build.`

Only the exact value `yes` turns on the failpoint build. Set it to `yes`, or unset it to install the official build:

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

## `the failpoint build needs git, go, make on PATH; not found: go`

The failpoint build clones etcd, then runs Go and GNU Make, and one of those programs is not on `PATH` when `vfox install` runs. The install stops before anything is cloned. Install the missing program, or put the directory that holds it on `PATH`, and install again.

## `etcd 3.6.0 was built without failpoints: ... does not link the gofail runtime. Uninstall the version and install it again.`

The build finished, but its binary has no gofail runtime, so the plugin refuses the install rather than report a build with failpoints that has none. Remove the version, and install it again:

```bash
vfox uninstall etcd@3.6.0
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.6.0
```

## `etcd build with failpoint failed, check the output above for details.`

The output above the message shows the command that failed. The usual causes are a missing Git, Go or GNU Make, or a Go version that the etcd release does not accept. A failed build can leave a partial clone behind, so remove the version before you try again:

```bash
vfox uninstall etcd@3.5.12
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

The build is only complete when its binary links the gofail runtime, which the plugin checks. For 3.4 and 3.5, `etcd --version` also prints `-FAILPOINTS` in its Git SHA.

## etcd 3.5.12 is not installed, run `vfox install etcd@3.5.12` first

`vfox use` was given a version that is not installed. Install it, or use `vfox search etcd` to find one.

## `vfox link --detect` does nothing or is unknown

Detection needs vfox 1.1.0 or later. Check with `vfox --version` and upgrade vfox. If no installation is found, see the list in [link.md](link.md): an etcd outside those places can still be linked by hand with `vfox link`.

## `etcd 3.5.5 has no failpoint build: its Makefile has no gofail target, so the build cannot run it. Pick a release that has one, such as 3.5.12, or unset BUILD_WITH_FAILPOINT to install the official build.`

The plugin reads the Makefile at the tag of the release before it clones etcd. This release has no gofail target in it, so the install stops before anything is cloned. Pick a release that has one, such as 3.5.12, or unset the variable to install the official build:

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

## `No rule to make target 'install-gofail'`

The plugin reads the Makefile at the tag before it clones etcd, and refuses a release without a gofail target. So this error means that the Makefile it read has a target that make did not find: report it with the release number. Failpoint builds were tested with etcd 3.4.32, 3.5.12 and 3.6.0. Use one of the tested releases for `BUILD_WITH_FAILPOINT=yes`, and see [failpoint.md](failpoint.md).

## vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'

`vfox use` runs only after vfox is hooked into the shell. Activate it first, then select the version:

```bash
eval "$(vfox activate bash)"
vfox use -g etcd@3.5.12
```

In PowerShell, use `Invoke-Expression "$(vfox activate pwsh)"` instead.

## `etcd --version` shows a different version than the one selected

Another etcd comes first on `PATH`. Check which one runs:

```bash
command -v etcd
```

Make sure vfox is activated in your shell (see its [quick start](https://vfox.dev/guides/quick-start.html)), then select the version again with `vfox use`.

## `etcd` is not found in PowerShell

Activate vfox in the profile, so it applies to every PowerShell session:

```powershell
Invoke-Expression "$(vfox activate pwsh)"
```
