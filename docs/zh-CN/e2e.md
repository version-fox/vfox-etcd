# 端到端测试

[中文](e2e.md) | [English](../e2e.md)

端到端测试套件会安装 vfox，使用由当前代码检出内容打包而成的 ZIP 添加插件，并像用户那样操作插件。它们位于 `tests/e2e` 中，每个平台对应一个 Go 包，且只使用 Go 标准库。

## 测试套件

| 包 | 运行环境 | 验证内容 |
| --- | --- | --- |
| `unix` | 宿主机上的 Ubuntu 和 macOS | 发布包安装后，`etcd`、`etcdctl` 和 `etcdutl` 位于 `PATH` 中；系统中的 etcd 通过 `vfox link --detect etcd` 接管并可以使用；etcd 3.5.12 的 failpoint 构建，其 gofail 端点会列出 failpoint。 |
| `linux` | 由 `tests/e2e/linux/Dockerfile` 构建的最小化 Ubuntu 24.04 容器 | 发布包安装不需要构建软件包；系统中的 etcd 会在容器内被检测并使用。 |
| `windows` | 宿主机上的 Windows，使用 PowerShell | 发布包安装后，三个命令位于 `PATH` 中；系统中的 etcd 通过 `vfox link --detect etcd` 接管并可以使用。 |

每个测试套件都会从发布包中安装 vfox 1.1.0，并对照 Go 源码中固定的 SHA-256 校验该发布包。发布新的 vfox 版本时，需要修改 `tests/e2e/common/common.go` 中的 `VfoxVersion` 及其 checksum，修改 `tests/e2e/linux/Dockerfile` 中的 `VFOX_VERSION` 和 `VFOX_SHA256` 参数，并同时修改 `.github/workflows/test.yml` 中相同的两个值。

系统安装是模拟的：测试套件会先把 etcd 二进制文件复制到它自己的目录中，并在运行 `vfox link --detect etcd -y` 之前把该目录加入 `PATH`。它期望的名称由所在位置决定：通常为 `<version>-path`，位于 `/opt` 时则为 `-opt`。

每个脚本在选择版本之前都会先激活 vfox，因为没有激活钩子时 `vfox use` 会拒绝运行：Bash 中使用 `eval "$(vfox activate bash)"`，PowerShell 中使用 `Invoke-Expression "$(vfox activate pwsh)"`。

## 运行测试

```bash
cd tests/e2e

# unit tests of the helpers; no network, no Docker
go test -short ./...

# the native suite on this host; downloads vfox and etcd, and builds a failpoint etcd
go test -v -timeout 60m ./unix

# the container suite; builds the image and needs Docker
go test -v -timeout 40m -run TestContainerE2E ./linux

# the Windows suite, on a Windows host
go test -v -timeout 60m ./windows
```

failpoint 构建需要 Git、Go 和 GNU Make，并且会耗时数分钟。`go test -run 'TestNativeE2E/(archive|system)' ./unix` 可以单独运行较快的场景。

测试套件会把 `HOME` 和 `USERPROFILE` 设置为临时目录，因此不会触及你的 vfox 安装。它们会保留你的 Go 构建缓存和模块缓存，使 failpoint 构建无需从零编译；gofail 二进制文件则放在临时目录中。failpoint 场景拥有自己的 vfox 主目录，因为发布包安装中已经包含 etcd 3.5.12。

## 在 CI 中运行

`e2e.yml` 工作流运行四个任务：`unix` 套件分别在 `ubuntu-latest` 和 `macos-latest` 上运行，容器套件在 `ubuntu-latest` 上运行，`windows` 套件在 `windows-latest` 上运行。向拉取请求推送新提交时，新的运行会替换之前的运行。
