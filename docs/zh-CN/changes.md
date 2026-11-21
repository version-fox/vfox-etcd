# 变更日志

[中文](changes.md) | [English](../changes.md)

以下是每个发布版本中用户能够感知到的变化。GitHub 的发布页面列出了对应的拉取请求。

## Unreleased

- `vfox link --detect etcd` 会找到机器上已经安装的 etcd，并将它们链接进来，而不再下载另一份副本。该功能需要 vfox 1.1.0 或更高版本。每个安装都以其版本及发现位置命名，例如 `3.5.12-system` 或 `3.5.12-brew`。参见 [link.md](link.md)。
- `BUILD_WITH_FAILPOINT=yes` 会构建你所安装版本对应的发布标签，而不是默认分支。早期版本克隆的是默认分支，因此 `vfox install etcd@3.4.32` 构建出的 etcd 与所指定的版本不同。该构建会把 gofail 加入 `PATH` 并设置 `FAILPOINTS=true`，缺少其中任何一项，二进制文件中就没有任何 failpoint。该构建已在 etcd 3.4.32 和 3.5.12 上测试，etcd 3.6.0 则会因错误而中止。参见 [failpoint.md](failpoint.md)。
- 在 Windows 上设置 `BUILD_WITH_FAILPOINT=yes` 时，会打印一条提示，并安装官方构建版本。此前该设置会被悄无声息地忽略。
- 若某个发布包的 checksum 不在该发布版本的 `SHA256SUMS` 中，现在将不再在未经校验的情况下安装它。安装会中止，并指出该文件。参见 [troubleshooting.md](troubleshooting.md)。
- 不是发布版本的版本号（例如 `3.5` 或 `3.5.12; rm`），会在任何下载开始之前被拒绝。
- 对未安装的版本执行 `vfox use` 时，会说明如何安装该版本，而不再因 Lua 错误而失败。
- 下载版本列表或 `SHA256SUMS` 失败时，安装会中止，并显示 URL 和 HTTP 状态码。此前安装会在没有 checksum 的情况下继续，而版本列表下载失败则会出现 Lua 错误。
- `vfox search etcd` 只列出插件可以安装的版本。只有当某个发布版本的 `SHA256SUMS` 列出了 linux-amd64 发布包时，它才会被列出。没有该文件的发布版本（插件现在拒绝在此情况下安装）不再列出，因此 `latest` 会选择一个可以安装的版本。列表从 310 个版本减少到 134 个。参见 [versions.md](versions.md)。
- 插件描述和文档现在写作 `etcdutl`，此前误写为 `etcductl`。

面向维护者：

- 在 Ubuntu、macOS 和 Windows 上运行 lint、离线插件测试、许可证头检查、文档配对检查以及端到端测试套件。中文页面会与英文页面进行对照检查。
- `.github/workflows/e2e_test.yaml` 已被 `.github/workflows/e2e.yml` 取代。
- 无法连接 GitHub 时，版本更新程序会失败。此前它会保留旧的列表，并以成功状态退出。设置了令牌时，它也会发送该令牌。

## 0.2.0 (2024-05-19)

- 通过 `BUILD_WITH_FAILPOINT=yes` 构建带 failpoint 的 etcd。
- 将下载的发布包与 etcd 发布的 SHA-256 进行校验。
- 对于以 failpoint 方式构建的版本，`vfox use` 能正常工作。
- `vfox search etcd` 按从新到旧的顺序列出版本，并获取更多版本。
- README 中有一个徽章和一个标志。
