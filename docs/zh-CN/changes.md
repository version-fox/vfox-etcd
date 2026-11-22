# 变更日志

[中文](changes.md) | [English](../changes.md)

以下是每个发布版本中用户能够感知到的变化。GitHub 的发布页面列出了对应的拉取请求。

## Unreleased

- `vfox search etcd` 读取插件自身发布标签处的版本列表，因此每个发布版本列出的都是它发布时的版本。默认分支上陈旧的列表副本不再改变某个发布版本的显示结果。刷新后的列表随下一个发布版本到达用户。参见 [versions.md](versions.md)。
- `BUILD_WITH_FAILPOINT=yes` 可以构建带 failpoint 的 etcd 3.6.0。对于有 `gofail-enable` 目标的发布版本，插件会运行 `make gofail-enable`（3.6.0 把该目标定义在被包含的 makefile 中）；若二进制文件中没有 gofail 运行时，构建会被视为错误，而不是显示为成功的安装。参见 [failpoint.md](failpoint.md)。
- `BUILD_WITH_FAILPOINT` 只接受 `yes`。`1` 或 `true` 等其他值会使安装因提示信息而中止。此前它们会悄无声息地安装官方构建版本。未设置或为空的变量，以及 `no`，仍会安装官方构建版本。
- failpoint 构建在克隆 etcd 之前检查 `git`、`go` 和 `make`，并指出缺少的那一个。
- 网站上的 failpoint 示例改用 etcd 3.5.12，该构建已在此版本上测试过。使用 3.5.5 的示例失败了。
- `vfox link --detect etcd` 能找到以标签形式打印版本的 etcd，例如 0.3.0 发布版本输出的 `v0.3.0`。
- 英文版本页面现在说明：早于 3.4.0 的发布版本，其发布包会按插件固定的 SHA-256 进行校验，与代码一致。

## 0.2.1 (2026-11-21)

- `vfox link --detect etcd` 会找到机器上已经安装的 etcd，并将它们链接进来，而不再下载另一份副本。该功能需要 vfox 1.1.0 或更高版本。每个安装都以其版本及发现位置命名，例如 `3.5.12-system` 或 `3.5.12-brew`。参见 [link.md](link.md)。
- `BUILD_WITH_FAILPOINT=yes` 会构建你所安装版本对应的发布标签，而不是默认分支。早期版本克隆的是默认分支，因此 `vfox install etcd@3.4.32` 构建出的 etcd 与所指定的版本不同。该构建会把 gofail 加入 `PATH` 并设置 `FAILPOINTS=true`，缺少其中任何一项，二进制文件中就没有任何 failpoint。该构建已在 etcd 3.4.32 和 3.5.12 上测试，etcd 3.6.0 则会因错误而中止。参见 [failpoint.md](failpoint.md)。
- 在 Windows 上设置 `BUILD_WITH_FAILPOINT=yes` 时，会打印一条提示，并安装官方构建版本。此前该设置会被悄无声息地忽略。
- 若某个发布包的 checksum 不在该发布版本的 `SHA256SUMS` 中，现在将不再在未经校验的情况下安装它。安装会中止，并指出该文件；但早于 3.4.0 的发布版本大多没有校验和，它们的发布包会与插件中固定的 SHA-256 值进行核对，安装时会给出说明。参见 [troubleshooting.md](troubleshooting.md)。
- 不是发布版本的版本号（例如 `3.5` 或 `3.5.12; rm`），会在任何下载开始之前被拒绝。
- 对未安装的版本执行 `vfox use` 时，会说明如何安装该版本，而不再因 Lua 错误而失败。
- 下载版本列表或 `SHA256SUMS` 失败时，安装会中止，并显示 URL 和 HTTP 状态码。此前安装会在没有 checksum 的情况下继续，而版本列表下载失败则会出现 Lua 错误。
- `vfox search etcd` 只列出插件可以在 Linux amd64 上安装的版本：当某个发布版本的 `SHA256SUMS` 列出了该发布包，或该版本早于 3.4.0 且其发布包可以下载时，它才会被列出。没有 linux-amd64 发布包的版本（例如 0.1.0 和 3.8.0-alpha.0），以及 3.4.0 或更高却没有校验和的版本（例如 3.5.0-alpha.0），不再列出，因此 `latest` 会选择一个可以安装的版本。列表从 310 个版本减少到 291 个。参见 [versions.md](versions.md)。
- 插件描述和文档现在写作 `etcdutl`，此前误写为 `etcductl`。

面向维护者：

- 在 Ubuntu、macOS 和 Windows 上运行 lint、离线插件测试、许可证头检查、文档配对检查以及端到端测试套件。中文页面会与英文页面进行对照检查。
- `.github/workflows/e2e_test.yaml` 已被 `.github/workflows/e2e.yml` 取代。
- 无法连接 GitHub 时，版本更新程序会失败。此前它会保留旧的列表，并以成功状态退出。设置了令牌时，它也会发送该令牌。
- 旧版本的 SHA-256 固定值保存在 `lib/pinned_checksums.lua` 中，由 `assets/pin_old_checksums.py` 写入，参见 [development.md](development.md)。

## 0.2.0 (2024-05-19)

- 通过 `BUILD_WITH_FAILPOINT=yes` 构建带 failpoint 的 etcd。
- 将下载的发布包与 etcd 发布的 SHA-256 进行校验。
- 对于以 failpoint 方式构建的版本，`vfox use` 能正常工作。
- `vfox search etcd` 按从新到旧的顺序列出版本，并获取更多版本。
- README 中有一个徽章和一个标志。
