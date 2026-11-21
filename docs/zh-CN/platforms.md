# 平台

[中文](platforms.md) | [English](../platforms.md)

插件会安装 etcd 为你所在平台发布的发布包。能提供哪些发布包取决于具体的发布版本。发布版本通常会在 `SHA256SUMS` 中列出它的发布包，而早于 3.4.0 的发布版本大多没有该文件，参见 [troubleshooting.md](troubleshooting.md)。

| 操作系统 | CPU | 发布包 | 说明 |
| --- | --- | --- | --- |
| Linux | amd64, arm64, ppc64le, s390x | `.tar.gz` | 发布包不需要额外的软件包。failpoint 构建需要 Git、Go 和 GNU Make。 |
| macOS | amd64, arm64 | `.zip` | arm64 发布包从 3.5.5 开始提供；3.4.32 只有 amd64 发布包。 |
| Windows | amd64 | `.zip` | 不支持 `BUILD_WITH_FAILPOINT`，改为安装官方构建版本。 |

表中列出的 CPU，是 etcd 3.5.12 为其发布了发布包的那些 CPU。插件会请求以 vfox 所报告的 CPU 名称命名的发布包，因此，只要 etcd 发布了某个发布包，它在上述任一 CPU 上的安装方式都相同。

CI 会在 Ubuntu（amd64）、macOS 和 Windows（amd64）上运行端到端测试套件。参见 [e2e.md](e2e.md)。

## 检查发布版本

要查看某个发布版本有哪些发布包，请读取它的 checksum 文件：

```bash
curl -fsSL https://github.com/etcd-io/etcd/releases/download/v3.5.12/SHA256SUMS
```

如果没有适用于你所在平台的发布包，请选择其他发布版本，或者从源码构建带有 [failpoints](failpoint.md) 的 etcd，该方式适用于 Linux 和 macOS。
