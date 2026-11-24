# 从源码安装

[中文](install-from-source.md) | [English](../install-from-source.md)

`vfox add etcd` 只添加插件，`vfox install etcd@latest` 会安装最新的发布版本。若要试用 `main`、某个分支，或你正在开发的改动，请从源码构建插件。插件由 `metadata.lua` 加上 `hooks` 和 `lib` 目录组成，vfox 会从包含它们的 zip 文件中添加插件。

## Ubuntu 和 macOS

在 Ubuntu 上，请先安装 `git` 和 `zip`。macOS 已经包含这两者。请在 Bash 中执行：

```bash
sudo apt install --assume-yes git zip
git clone --depth 1 https://github.com/version-fox/vfox-etcd.git
cd ./vfox-etcd/
zip -qr ./etcd.zip metadata.lua hooks lib
vfox add etcd --source ./etcd.zip
rm ./etcd.zip
```

若要试用某个分支，请改为克隆该分支：

```bash
git clone --depth 1 --branch <branch> https://github.com/version-fox/vfox-etcd.git
```

## Windows 11

假定你已经安装了 PowerShell 7。请在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
git clone --depth 1 https://github.com/version-fox/vfox-etcd.git
cd ./vfox-etcd/
tar -a -cf ./etcd.zip metadata.lua hooks lib
vfox add etcd --source ./etcd.zip
Remove-Item ./etcd.zip
```

## 检查

```bash
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
etcd --version
```

在上面的示例中，`etcd --version` 会输出 `etcd Version: 3.5.12`。

## etcd 已经添加时

`vfox add` 会拒绝执行，并显示 `plugin named etcd already exists`。你可以替换该插件，也可以用其他名称添加源码构建的版本。

若要替换，请先移除该插件。`vfox remove` 也会移除通过该插件安装的 etcd 版本，并且 vfox 会在询问之前说明这一点。之后请重新安装这些版本。

```bash
vfox remove -y etcd
vfox add etcd --source ./etcd.zip
```

若要两者都保留，请用其他名称添加源码构建的版本。alias 本身是一个独立的插件：

```bash
vfox add etcd --source ./etcd.zip --alias etcd-dev
```

`vfox remove -y etcd-dev` 只会移除该插件本身，以及它安装的 etcd 版本。

## 更新

拉取最新的源码，重新压缩为 zip，然后再次添加插件：

```bash
cd ./vfox-etcd/
git pull
zip -qr ./etcd.zip metadata.lua hooks lib
vfox remove -y etcd
vfox add etcd --source ./etcd.zip
rm ./etcd.zip
```

只有当注册表中的版本比 `metadata.lua` 中的版本更新时，`vfox update etcd` 才会替换源码构建的版本。当两个版本相同时，它会输出 `etcd is already the latest version`，并保留源码构建的版本。

若要修改插件，请参阅 [development.md](development.md)。
