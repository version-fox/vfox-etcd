# 故障排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

下面的消息来自插件本身，或者来自 vfox 运行插件钩子（hooks）时输出的内容。

插件拒绝安装时，它只打印消息，不附带堆栈回溯，随后 vfox 会报告 `no installable runtime provided`。插件抛出的其他错误，例如下载失败，仍会附带堆栈回溯。

## `invalid etcd version 3.5`

插件需要完整的发布版本，例如 `3.5.12`。不完整的版本号会被拒绝，因为它们无法指向唯一的下载文件：

```bash
vfox search etcd
vfox install etcd@3.5.12
```

## `there is no etcd release 9.9.9, see https://github.com/etcd-io/etcd/releases for the releases that exist`

该版本号是完整的发布版本号，但 GitHub 上没有这个名称的 etcd 发布版本。插件会在下载发布包、校验和或源码之前停止。请检查拼写，并从列表中选择一个发布版本：

```bash
vfox search etcd
vfox install etcd@3.5.12
```

`vfox search etcd` 列出的是可以在 Linux amd64 上安装的发布版本，请从中选择。

## `etcd 3.7.4 has no Windows arm64 build, see https://github.com/etcd-io/etcd/releases/tag/v3.7.4 for the archives it has`

该发布版本没有适用于你所在平台的发布包，因此安装会在下载发布包之前停止。消息之后不会出现堆栈回溯。vfox 随后会报告 `no installable runtime provided`，这是插件的 `PreInstall` 没有返回任何结果时 vfox 报告的内容。请选择有适用发布包的发布版本，或阅读 [platforms.md](platforms.md)。etcd 在任何发布版本中都没有发布适用于 Windows 的 arm64 发布包，因此在 Windows arm64 上，应当预期看到这条消息。例如，3.4.32 没有适用于 Apple 芯片的发布包，而 macOS 的 arm64 发布包从 3.5.5 开始提供。

## `could not download https://github.com/etcd-io/etcd/releases/download/v3.5.0-alpha.0/SHA256SUMS: HTTP 404`

该发布版本没有发布 `SHA256SUMS`，且版本号为 3.4.0 或更高。插件不会在没有校验和的情况下安装此类发布版本的发布包，因此安装会中止。请选择 3.4.0 或更高、且发布了该文件的版本。早于 3.4.0 的发布版本会改用固定的校验值进行核对，参见下一节。

## `etcd 0.4.9 publishes no checksum for ..., so the archive is checked against the SHA-256 pinned in this plugin.`

该发布版本早于 3.4.0，其 `SHA256SUMS` 中没有该发布包的条目，或者根本没有该文件。插件会用为该发布包固定的 SHA-256 值进行核对，并在安装前打印这一行。这些固定值取自插件固定时 GitHub 提供的发布包，因此该检查能发现之后的变动，但无法发现固定时下载到的文件本身有问题。

## `etcd 3.3.13 has no Windows arm64 build that the plugin has a checksum for, see https://github.com/etcd-io/etcd/releases/tag/v3.3.13 for the archives it has`

该发布版本早于 3.4.0。它的 `SHA256SUMS` 可能不存在，或者没有列出你所在平台的发布包，而插件也没有为该发布包固定校验值。插件不会安装无法校验的发布包，因此安装会在下载发布包之前停止，消息之后不会出现堆栈回溯。消息没有说该发布版本没有构建，因为插件只知道它固定了哪些发布包。请选择其他发布版本，或参阅 [platforms.md](platforms.md)。

## `could not download https://...`

插件无法连接 GitHub，或者 GitHub 返回了一个错误，该错误会连同其 HTTP 状态码一起显示。请检查你的网络和任何代理设置，然后重新运行该命令。版本列表来自 jsDelivr，因此 `vfox search etcd` 也可能因为同样的网络问题而失败。

## `BUILD_WITH_FAILPOINT is only supported on Linux and macOS, installing the official Windows build.`

在 Windows 上，插件会安装官方构建版本，并打印这一提示。请将该变量从环境变量中移除，以停止显示此提示。关于 Linux 和 macOS 构建需要满足的条件，请参见 [failpoint.md](failpoint.md)。

## `BUILD_WITH_FAILPOINT is "1", but only yes turns on the failpoint build. Unset it to install the official build.`

只有精确的值 `yes` 才会启用 failpoint 构建。请设为 `yes`，或取消设置以安装官方构建版本：

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

## `the failpoint build needs git, go, make on PATH; not found: go`

failpoint 构建需要克隆 etcd，并运行 Go 和 GNU Make，而其中某个程序在运行 `vfox install` 时不在 `PATH` 中。安装会在克隆任何内容之前停止。请安装缺少的程序，或把包含它的目录加入 `PATH`，然后重新安装。

## `etcd 3.6.0 was built without failpoints: ... does not link the gofail runtime. Uninstall the version and install it again.`

构建已完成，但其二进制文件中没有 gofail 运行时，因此插件会拒绝此次安装，而不是把一个没有 failpoint 的构建当作成功。请移除该版本，然后重新安装：

```bash
vfox uninstall etcd@3.6.0
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.6.0
```

## `etcd build with failpoint failed, check the output above for details.`

消息上方的输出会显示失败的命令。常见原因是缺少 Git、Go 或 GNU Make，或者所用的 Go 版本不被该 etcd 发布版本接受。失败的构建可能会留下一个不完整的克隆，因此在重试之前，请先删除该版本：

```bash
vfox uninstall etcd@3.5.12
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

只有当其二进制文件链接了 gofail 运行时（插件会检查这一点）时，构建才算完成。对于 3.4 和 3.5，`etcd --version` 还会在其 Git SHA 中输出 `-FAILPOINTS`。

## etcd 3.5.12 is not installed, run `vfox install etcd@3.5.12` first

`vfox use` 指定的版本尚未安装。请安装该版本，或使用 `vfox search etcd` 查找一个可用的版本。

## `vfox link --detect` 没有作用或不被识别

检测功能需要 vfox 1.1.0 或更高版本。请使用 `vfox --version` 检查版本，并升级 vfox。如果没有找到任何安装，请参阅 [link.md](link.md) 中的列表：不在这些位置的 etcd 仍然可以通过 `vfox link` 手动链接。

## `etcd 3.5.5 has no failpoint build: its Makefile has no gofail target, so the build cannot run it. Pick a release that has one, such as 3.5.12, or unset BUILD_WITH_FAILPOINT to install the official build.`

插件会在克隆 etcd 之前读取该发布版本标签处的 Makefile。3.5.5 的 Makefile 中没有 gofail 目标，因此安装会在克隆任何内容之前停止。请选择带有该目标的发布版本，例如 3.5.12，或取消设置该变量以安装官方构建版本：

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

## `No rule to make target 'install-gofail'`

插件会在克隆 etcd 之前读取标签处的 Makefile，并拒绝其中没有 gofail 目标的发布版本。因此出现这个错误，说明插件读取的 Makefile 中有该目标，而 make 却没有找到它。请附上发布版本号报告此问题。failpoint 构建已在 etcd 3.4.32、3.5.12 和 3.6.0 上测试过。使用 `BUILD_WITH_FAILPOINT=yes` 时，请选择其中一个经过测试的发布版本，并参阅 [failpoint.md](failpoint.md)。

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
