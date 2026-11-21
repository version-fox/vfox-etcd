# 版本

[中文](versions.md) | [English](../versions.md)

本插件从 GitHub 安装 etcd 的发布版本。版本即发布编号，其写法与 etcd 为 Git 标签（tag）命名的方式相同，例如 `3.5.12`。预发布版本同样可用，例如 `3.8.0-alpha.0`。

## 搜索

`vfox search etcd` 会列出插件可以安装的版本。该列表保存在默认分支的 `assets/versions.txt` 中，并由一个工作流每周根据 etcd 的 Git 标签刷新一次。只有当某个发布版本的 linux-amd64 发布包可以安装时，它才会被列出：其 `SHA256SUMS` 列出了该发布包，或者该版本早于 3.4.0，插件会用为其发布包固定的 SHA-256 值进行校验。因此 `latest` 指的是 Linux amd64 上可以安装的最新发布版本。其他平台可能缺少已列出版本的发布包，参见 [platforms.md](platforms.md)。

## 安装

```bash
vfox install etcd@3.5.12
```

vfox 会从 etcd 的发布版本中下载适用于你平台的发布包，并与该发布版本在 `SHA256SUMS` 中公布的 SHA-256 进行核对。如果该文件中没有你平台的条目，安装会因 `no checksum for ...` 而中止：这说明该发布版本没有适用于你平台的构建，参见 [platforms.md](platforms.md)。早于 3.4.0 的发布版本可能完全没有校验和文件。此时插件会用为其发布包固定的 SHA-256 值进行校验，并在安装前说明这一点，参见 [troubleshooting.md](troubleshooting.md)。

请给出完整的版本号。像 `etcd@3.5` 这样的不完整版本会被拒绝并显示 `invalid etcd version`，因为插件无法判断它指的是哪一个发布版本。

## 选择

```bash
vfox use etcd@3.5.12        # this shell only
vfox use -g etcd@3.5.12     # every new shell
vfox use -p etcd@3.5.12     # the project in the current directory
```

选择版本后，`etcd`、`etcdctl` 和 `etcdutl` 就是该版本对应的程序。请使用以下命令检查：

```bash
etcd --version
etcdctl version
etcdutl version
```

如果 `vfox use` 提示该版本未安装，请先运行 `vfox install etcd@<version>`。对于 vfox 从已有安装中链接的版本（参见 [link.md](link.md)），应使用其链接名称进行选择，例如 `etcd@3.5.12-system`。

## 卸载

```bash
vfox uninstall etcd@3.5.12
```

卸载链接的版本时只会删除该链接，它所指向的 etcd 会保留在原来的位置。
