# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

The plugin installs etcd releases from GitHub. A version is the release number, written the way etcd names its tags, such as `3.5.12`. Pre-releases work too, such as `3.7.0-rc.0`.

## Search

`vfox search etcd` lists the versions the plugin can install. The list is kept in `assets/versions.txt`, and a workflow refreshes it every week on the default branch from the etcd tags. Each plugin release reads the list at its own release tag, so a release shows the versions it was released with, and a refreshed list reaches users with the next release. A release is listed when its linux-amd64 archive can be installed: its `SHA256SUMS` lists the archive, or the release is older than 3.4.0 and its archives are checked against SHA-256 values pinned in the plugin. So `latest` is the newest release that installs on Linux amd64. Another platform may lack the archive of a listed version, see [platforms.md](platforms.md).

## Install

```bash
vfox install etcd@3.5.12
```

vfox downloads the archive for your platform from the etcd release and checks it against the SHA-256 that the release publishes in `SHA256SUMS`. If that file has no entry for your platform, the install stops with `no checksum for ...`: the release has no build for your platform, see [platforms.md](platforms.md). A release older than 3.4.0 may publish no checksum at all. Its archive is then checked against the SHA-256 that the plugin pins for it, and the plugin says so before it installs, see [troubleshooting.md](troubleshooting.md).

Give the full version. A partial version such as `etcd@3.5` is refused with `invalid etcd version`, because the plugin cannot tell which release it means.

## Select

```bash
vfox use etcd@3.5.12        # this shell only
vfox use -g etcd@3.5.12     # every new shell
vfox use -p etcd@3.5.12     # the project in the current directory
```

After a selection, `etcd`, `etcdctl` and `etcdutl` are the ones of that version. Check them with:

```bash
etcd --version
etcdctl version
etcdutl version
```

If `vfox use` says the version is not installed, run `vfox install etcd@<version>` first. A version that vfox has linked from an existing installation, see [link.md](link.md), is selected by its linked name, such as `etcd@3.5.12-system`.

## Remove

```bash
vfox uninstall etcd@3.5.12
```

Removing a linked version removes only the link. The etcd it points to stays where it is.
