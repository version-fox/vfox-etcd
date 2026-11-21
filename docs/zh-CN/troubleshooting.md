# 故障排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

下面的消息来自插件本身，或者来自 vfox 运行插件钩子（hooks）时输出的内容。

## `invalid etcd version 3.5`

插件需要完整的发布版本，例如 `3.5.12`。不完整的版本号会被拒绝，因为它们无法指向唯一的下载文件：

```bash
vfox search etcd
vfox install etcd@3.5.12
```

## `no checksum for etcd-v3.4.32-darwin-arm64.zip in ...`

该发布版本没有适用于你所在平台的发布包。消息中会写明插件所需的那个发布包。请选择包含该发布包的发布版本，或阅读 [platforms.md](platforms.md)。例如，3.4.32 没有适用于 Apple 芯片的发布包，而 macOS 的 arm64 发布包从 3.5.5 开始提供。

## `could not download https://github.com/etcd-io/etcd/releases/download/v3.5.0-alpha.0/SHA256SUMS: HTTP 404`

该发布版本没有发布 `SHA256SUMS`，且版本号为 3.4.0 或更高。插件不会在没有校验和的情况下安装此类发布版本的发布包，因此安装会中止。请选择 3.4.0 或更高、且发布了该文件的版本。早于 3.4.0 的发布版本是例外，参见下一节。

## `WARNING: etcd 3.3.13 publishes no checksum for etcd-v3.3.13-linux-amd64.tar.gz, so the archive is installed without a check.`

该版本早于 3.4.0，其发布版本没有该发布包的 checksum。插件会先打印这条警告，然后在不进行校验的情况下安装该发布包。vfox 也会打印 `WARNING: Checksum is not provided, skip verify...`。如需校验该发布包，请安装 3.4.0 或更高版本的发布版本。此处除了从 GitHub 通过 HTTPS 下载之外没有其他检查，因此该发布包的可信程度仅取决于这次下载。

## `could not download https://...`

插件无法连接 GitHub，或者 GitHub 返回了一个错误，该错误会连同其 HTTP 状态码一起显示。请检查你的网络和任何代理设置，然后重新运行该命令。版本列表来自 jsDelivr，因此 `vfox search etcd` 也可能因为同样的网络问题而失败。

## `BUILD_WITH_FAILPOINT is only supported on Linux and macOS`

在 Windows 上，该变量会被忽略，并改为安装官方构建版本。请将它从环境变量中移除，以停止显示此提示。关于 Linux 和 macOS 构建需要满足的条件，请参见 [failpoint.md](failpoint.md)。

## `etcd build with failpoint failed, check the output above for details.`

消息上方的输出会显示失败的命令。常见原因是缺少 Git、Go 或 GNU Make，或者所用的 Go 版本不被该 etcd 发布版本接受。失败的构建可能会留下一个不完整的克隆，因此在重试之前，请先删除该版本：

```bash
vfox uninstall etcd@3.5.12
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

只有当 `etcd --version` 在其 Git SHA 中输出 `-FAILPOINTS` 时，构建才算完成。

## etcd 3.5.12 is not installed, run `vfox install etcd@3.5.12` first

`vfox use` 指定的版本尚未安装。请安装该版本，或使用 `vfox search etcd` 查找一个可用的版本。

## `vfox link --detect` 没有作用或不被识别

检测功能需要 vfox 1.1.0 或更高版本。请使用 `vfox --version` 检查版本，并升级 vfox。如果没有找到任何安装，请参阅 [link.md](link.md) 中的列表：不在这些位置的 etcd 仍然可以通过 `vfox link` 手动链接。

## `No rule to make target 'install-gofail'`

该发布版本的 Makefile 中没有 gofail 目标。failpoint 构建已在 etcd 3.4.32 和 3.5.12 上测试过，而 3.6.0 发布版本中没有这些目标。使用 `BUILD_WITH_FAILPOINT=yes` 时，请选择经过测试的发布版本之一，并参阅 [failpoint.md](failpoint.md)。

## vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'

只有在 vfox 已挂接到 shell 之后，`vfox use` 才会运行。请先激活 vfox，然后再选择版本：

```bash
eval "$(vfox activate bash)"
vfox use -g etcd@3.5.12
```

在 PowerShell 中，请改用 `Invoke-Expression "$(vfox activate pwsh)"`。

## `etcd --version` 显示的版本与所选版本不同

`PATH` 中排在最前面的是另一个 etcd。请检查实际运行的是哪一个：

```bash
command -v etcd
```

请确保你的 shell 中已激活 vfox（参见其[快速入门](https://vfox.dev/guides/quick-start.html)），然后使用 `vfox use` 重新选择版本。

## 在 PowerShell 中找不到 `etcd`

请在 PowerShell 的配置文件（profile）中激活 vfox，使其对每个 PowerShell 会话都生效：

```powershell
Invoke-Expression "$(vfox activate pwsh)"
```
