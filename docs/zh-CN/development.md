# 开发

[中文](development.md) | [English](../development.md)

本页面面向修改插件的人。关于如何使用插件，请参阅 [README](../../README_CN.md)。

## 目录结构

| 路径 | 用途 |
| --- | --- |
| `metadata.lua` | 插件名称、版本号以及所需的最低 vfox 版本。版本号由发布工作流设置。 |
| `hooks/` | 每个 vfox 钩子对应一个文件：`available.lua`、`pre_install.lua`、`post_install.lua`、`env_keys.lua`、`pre_use.lua` 和 `detect.lua`。 |
| `lib/` | 钩子所需的辅助模块：`etcd_utils.lua` 负责下载、checksum 和版本字符串，`pinned_checksums.lua` 保存旧版本的 SHA-256，`detect_etcd.lua` 负责查找已有的安装。 |
| `tests/` | `*_test.lua` 文件（由 `vfox plugin test` 离线运行），以及 `tests/e2e`，即安装插件的 Go 测试套件。 |
| `assets/` | `versions.txt`（即 `vfox search` 显示的已发布版本）、刷新该文件的脚本，以及写入 `lib/pinned_checksums.lua` 的 `pin_old_checksums.py`。 |
| `website/` | 中英文落地页，由 `website/build.py` 构建。 |
| `docs/` | 本文档的英文版，中文页面位于 `docs/zh-CN/` 下。 |
| `.github/` | 工作流、文档检查以及拉取请求模板。 |

## 各钩子的作用

- `Available` 列出 `assets/versions.txt` 中的版本。
- `PreInstall` 检查版本，并从发布版本的 `SHA256SUMS` 中返回发布包的 URL 和 checksum。早于 `3.4.0` 的发布版本可能没有该发布包的 checksum，此时会改用为该发布包固定的 SHA-256 值进行核对。在 Linux 或 macOS 上设置 `BUILD_WITH_FAILPOINT=yes` 时，它不返回发布包，因此会改为从源码构建。
- `PostInstall` 在被要求时运行 failpoint 构建。
- `EnvKeys` 把可执行文件放入 `PATH`。链接的系统安装位于 `bin/` 中，源码构建位于 `etcd/bin` 中，发布包则位于根目录。
- `PreUse` 拒绝使用未安装的版本。
- `Detect` 为 `vfox link --detect etcd` 扫描 etcd 的安装。参见 [link.md](link.md)。

## 检查

CI 会运行这些检查，拉取请求必须全部通过。请运行与你所修改文件对应的检查：

| 检查项 | 命令 | 运行位置 |
| --- | --- | --- |
| Lua 格式 | `stylua --check .` | `lint.yml` |
| Lua 诊断 | `lua-language-server --check . --checklevel=Warning` | `lint.yml` |
| 插件测试 | `vfox plugin test .`（vfox 1.1.0） | `test.yml` |
| 工作流文件 | `actionlint` | `lint.yml` |
| Python 格式与代码检查 | `ruff format --check .` 和 `ruff check .` | `lint.yml` |
| Go 格式、vet 与单元测试 | 在 `tests/e2e` 中运行 `gofmt -l .`、`go vet ./...` 和 `go test -short ./...` | `lint.yml` |
| 文档配对 | `python3 -I .github/scripts/check_docs_parity.py .` | `lint.yml` |
| 许可证头 | `license-eye header check -c .licenserc.yaml`（skywalking-eyes） | `license.yml` |
| 端到端测试 | 参见 [e2e.md](e2e.md) | `e2e.yml` |

这些工具均已固定版本：stylua 2.6.0、lua-language-server 3.19.1、actionlint 1.7.12、ruff 0.17.6、vfox 1.1.0 和 Go 1.27.1。修改某个固定版本时，需同时修改运行该工具的工作流以及本页面。

## 测试

`vfox plugin test .` 会在各自独立的虚拟机中运行每个 `tests/**/*_test.lua`，规则如下：

- 测试文件需调用一次 `require("vfox.test")` 和 `test.load(...)`。`test.load` 接收平台、环境，以及一个用于响应插件请求的 `http` 处理函数。
- `lib/` 中的辅助模块通过 `require` 加载，且须在 `package.path = "./lib/?.lua;" .. package.path` 之后进行。
- 测试可以在调用钩子之前替换其所需的函数，例如 `os.execute` 或 `etcd_utils.file_exists`。
- 这里无法让 `os.execute` 运行真实命令，因此构建和目录探测通过替换函数进行测试。端到端测试套件会运行真实的命令。

## 编写文档

`docs/` 中的每个页面都在 `docs/zh-CN/` 中有一个同名页面，`README.md` 则对应 `README_CN.md`。文档检查会在以下情况下失败：

- 某个页面没有配对的页面，
- 两个页面提到的 `VFOX_*`、`ETCD_*`、`BUILD_WITH_FAILPOINT` 或 `GOFAIL_*` 变量不一致，
- 两个页面的代码块数量不同，
- 相对链接无法解析。

翻译时只翻译句子，命令和代码块保持不变。每个页面的标题下方都有一行语言链接，两个页面都把中文放在前面。英文页面上，「中文」链接指向 `zh-CN/<page>`，「English」链接指向 `<page>`；中文页面上，「中文」链接指向 `<page>`，「English」链接指向 `../<page>`。

## 变更日志

每一项面向用户的变更，都要在 `docs/changes.md` 和 `docs/zh-CN/changes.md` 中、`## Unreleased` 标题下各添加一行。维护者发布时会重命名该标题。

## 许可证头

凡是可以包含注释的文件，都带有 Apache 2.0 许可证头，其版权声明为 `Copyright 2026 version-fox and contributors`。其中包括 Lua、Go、Python、YAML、TOML 和 Dockerfile 文件，以及 `.gitignore`。`license.yml` 工作流会依据 `.licenserc.yaml` 中的配置进行检查。无法包含注释的文件（例如 JSON、Markdown 和官方 logo）已在该配置中列为忽略项。

## 网站

站点首页仅使用标准库构建：

```bash
python3 website/build.py --output /tmp/vfox-etcd-site
python3 -m http.server 8080 --directory /tmp/vfox-etcd-site
```

部署说明参见 [website/README.md](../../website/README.md)。

## 发布

维护者可以在默认分支上通过 **Actions → Plugin → Run workflow** 发布，输入一个不带 `v` 前缀的稳定插件版本号即可。共享工作流会更新 `metadata.lua`、创建版本提交和标签，并在本仓库中发布 ZIP 和清单文件。无需本地标签或额外的发布令牌。拉取请求只运行检查。

当 `PLUGIN.version` 已与标签一致时，仍支持推送已有的版本标签。如果发布失败，请重新运行最初失败的任务以继续发布。

该工作流沿用共享的 `@v1` 发布工具版本。更新该工具并不会发布本插件。关于打包约定，请参阅[共享工作流文档](https://github.com/version-fox/plugin-manifest-action)。

## 版本列表

`assets/versions.txt` 由 `update_etcd_versions` 工作流每周一刷新。它通过 GitHub API 读取 etcd 的标签，并保留其 linux-amd64 发布包可以安装的版本：该发布版本的 `SHA256SUMS` 列出了此发布包，或者该版本早于 `3.4.0` 且该发布包可以下载，插件随后会用 `lib/pinned_checksums.lua` 中为它固定的 SHA-256 值进行校验。这些检查同时进行，最多 16 个。当无法连接 GitHub，或请求 `SHA256SUMS` 或发布包时返回的错误不是 404 时，它会失败，且不会修改列表；404 表示该发布版本不提供该文件。若要手动刷新，请在 `assets` 目录中运行它，并在 `GITHUB_TOKEN` 中提供令牌：

```bash
cd assets && python3 -m pip install requests packaging && python3 get_all_etcd_versions.py
```

## 固定的校验值

早于 `3.4.0` 的发布版本大多没有 `SHA256SUMS`，因此插件会用 `lib/pinned_checksums.lua` 中的 SHA-256 值核对它们的发布包。该文件由 `assets/pin_old_checksums.py` 写入：对于每个列出的旧版本，脚本会下载插件支持的每个平台中、其 `SHA256SUMS` 未列出的发布包，并记录 GitHub 提供的该发布包的哈希值。GitHub 不为这些资源发布摘要，因此没有独立的途径确认这些值。下载总量约 6 GB。脚本把进度保存在系统临时目录中，因此中断后可以续跑。请在仓库根目录运行：

```bash
python3 assets/pin_old_checksums.py
```

只有当旧版本列表变化时才需要重新运行，并请检查 `lib/pinned_checksums.lua` 的差异。
