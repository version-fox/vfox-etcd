# 带 failpoint 的 etcd

[中文](failpoint.md) | [English](../failpoint.md)

[Failpoints](https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally) 可以让测试在选定的位置使 etcd 失败，健壮性测试借此进行混沌测试。它们由 [gofail](https://github.com/etcd-io/gofail) 编译进来。官方发布包中都没有 failpoint，因此插件会在你需要时从源码构建 etcd：

```bash
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```

插件已在 etcd 3.4.32 和 3.5.12 上测试过。3.6.0 发布版本的 Makefile 中没有 gofail 目标，因此对它的构建会因错误而中止。

## 构建会做什么

设置 `BUILD_WITH_FAILPOINT=yes` 后，插件会跳过发布包的下载。vfox 创建安装目录之后，会在该目录中依次运行以下命令：

```bash
git clone --depth 1 --branch v3.5.12 https://github.com/etcd-io/etcd.git etcd
cd etcd
export PATH="$(go env GOBIN | grep . || echo "$(go env GOPATH | cut -d: -f1)/bin"):$PATH"
make install-gofail
FAILPOINTS=true make build
```

克隆的是你所请求版本的标签。0.2.1 之前的插件版本克隆的是默认分支，因此构建出的 etcd 与所指定的版本不同。

gofail 必须在 make 目标运行之前已位于 `PATH` 中。`go install` 会把它放入 `GOBIN`；若 `GOBIN` 为空，则放入 `GOPATH` 的第一个条目，因此命令会先把该目录加入 `PATH`。随后，构建会在 `FAILPOINTS=true` 的条件下运行，因为 etcd 的构建脚本只有在设置了该变量时才会启用 failpoint。带有 failpoint 的构建，其 Git SHA 中会包含 `-FAILPOINTS`，`etcd --version` 会将其打印出来。

3.4 系列有一个 `gofail-enable` 目标，它自身就会启用 failpoint。对于这些发布版本，插件会运行 `make gofail-enable`，代替 `make install-gofail`。

二进制文件最终位于安装目录中的 `etcd/bin`，选定该版本时，插件会把该目录加入 `PATH`。

## 所需条件

- Linux 或 macOS。在 Windows 上，`BUILD_WITH_FAILPOINT` 会打印一条提示，并安装官方构建版本。
- Git，用于克隆 etcd。
- Go，版本须符合该 etcd 发布版本的要求，并且在运行 `vfox install` 时已位于 `PATH` 中。
- GNU Make。

一次构建需要几分钟。构建输出会被打印出来，因此失败时会显示失败的命令。

## 使用方法

```bash
vfox use -g etcd@3.5.12

# start etcd with failpoints enabled
GOFAIL_HTTP="127.0.0.1:22381" etcd

# list the failpoints that were compiled in
curl http://127.0.0.1:22381
```

## 构建失败之后

构建中途失败时，安装目录中可能会留下一个不完整的克隆，之后的 `git clone` 便会拒绝写入该目录。请移除该版本后重新安装：

```bash
vfox uninstall etcd@3.5.12
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12
```
