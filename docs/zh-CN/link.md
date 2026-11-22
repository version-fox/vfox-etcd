# 使用已安装的 etcd

[中文](link.md) | [English](../link.md)

如果机器上已经装有 etcd，`vfox link --detect etcd` 会直接将其纳入管理，而不再下载另一份副本。该功能需要 vfox 1.1.0 或更高版本（可通过 `vfox --version` 查看）：

```bash
vfox link --detect etcd
```

vfox 会列出插件找到的安装，并询问要链接其中的哪些。使用 `-y` 可以不经询问，直接全部链接：

```bash
vfox link --detect etcd -y
```

已链接的版本是指向该安装的符号链接。不会复制任何内容：安装仍保留在原处，所有权也仍归其原所有者，`vfox uninstall` 只会删除链接本身。`vfox list etcd` 会标出已链接的版本。

## 查找位置

插件会先检查 `PATH` 中的每个目录，然后检查各系统的常见位置。只有当某个目录中包含 `etcd` 可执行文件（Windows 上为 `etcd.exe`），且该文件执行 `--version` 时能打印出版本（例如 `etcd Version: 3.5.12`，或标签形式的 `v0.3.0`）时，这个目录才会被计入。

| 来源 | 插件查找的位置 | 名称后缀 |
| --- | --- | --- |
| `PATH` | `PATH` 中的每个目录 | 依位置决定，见下文 |
| Linux 和 macOS | `/usr/bin`、`/usr/local/bin`、`/opt/homebrew/bin`、`/home/linuxbrew/.linuxbrew/bin` | `-system`、`-local`、`-brew` |
| Windows | `%ProgramFiles%\etcd`、`%ProgramFiles(x86)%\etcd` | `-system` |
| Scoop | `%USERPROFILE%\scoop\apps\etcd\current` | `-scoop` |

对于 `PATH` 中的目录，或上表中的某个位置，后缀取决于该目录所在的位置：

- `-system`：`/usr` 下的安装，以及 Windows 上 Program Files 下的安装；
- `-local`：`/usr/local` 下的安装；
- `-brew`：Homebrew 或 Cellar 目录下的安装；
- `-opt`：`/opt` 下的安装；
- `-scoop`：Scoop 目录下的安装；
- `-path`：其他任何位置的安装。

## 名称

名称的格式为 `<version>-<source>`，例如 `3.5.12-system` 或 `3.8.0-alpha.0-brew`。`vfox use` 通过该名称选择已链接的版本：

```bash
vfox use -g etcd@3.5.12-system
```

如果两个安装会得到相同的名称，则先找到的那个会使用该名称，并且 `PATH` 优先于固定目录。来源不同的安装会得到不同的名称：同一版本位于 `/usr/bin` 和 `/usr/local/bin` 下时，会得到 `3.5.12-system` 和 `3.5.12-local`。若两个副本的来源相同（例如两个位于 `PATH` 中的目录），它们都会得到 `3.5.12-path`，只会列出先找到的那个。

## 不计入的内容

插件会跳过以下内容：

- vfox 自己的安装，即 `VFOX_HOME/sdks/etcd` 和 `VFOX_HOME/cache/etcd` 下的安装（默认为 `~/.vfox/sdks/etcd` 和 `~/.vfox/cache/etcd`）；
- shim 目录，例如版本管理器加入 `PATH` 的那些目录，因为 shim 只会转发到其他位置的安装；
- 不会打印 etcd 版本的可执行文件；
- 已经列出过的目录。

## 手动链接目录

当 `--detect` 没有找到某个安装时，请自行链接。路径可以是包含 `bin` 的目录（其中有 `etcd`），也可以是根目录下直接包含 `etcd` 或 `etcd.exe` 的目录：

```bash
vfox link etcd@3.5.12-system /usr
vfox use -g etcd@3.5.12-system
```

已链接的名称可以通过 `--force` 改为指向其他位置：

```bash
vfox link --force etcd@3.5.12-system /usr/local
```

`--force` 绝不会替换 vfox 安装的版本，请先卸载该版本。

## 系统安装

通过包管理器安装的 etcd 由该包管理器维护。已链接的版本会跟随安装本身，因此系统包升级之后，它报告的版本也会随之改变。请再次运行 `vfox link --detect etcd`，为新版本获取一个名称。
