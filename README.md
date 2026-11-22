<div align="center">

![logo](./assets/vfox-etcd-logo.png)

[![Lint](https://github.com/version-fox/vfox-etcd/actions/workflows/lint.yml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/lint.yml)
[![E2E](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e.yml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e.yml)
[![Test](https://github.com/version-fox/vfox-etcd/actions/workflows/test.yml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/test.yml)
[![License](https://github.com/version-fox/vfox-etcd/actions/workflows/license.yml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/license.yml)

</div>

# vfox-etcd plugin

[中文](README_CN.md) | [English](README.md)

An [etcd](https://etcd.io/) plugin for [vfox](https://vfox.dev/). It installs several etcd versions side by side and switches between them, with `etcd`, `etcdctl` and `etcdutl` on the `PATH`, on Linux, macOS and Windows. It can also build etcd with [failpoints](docs/failpoint.md) for chaos testing, and adopt an etcd that is already on the machine with [`vfox link --detect etcd`](docs/link.md).

## Install

After installing [vfox](https://github.com/version-fox/vfox), add the plugin, install a version and select it:

```bash
vfox add etcd
vfox search etcd
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
etcd --version
```

`vfox add etcd` installs the latest release. To try `main`, a branch, or a change you are working on, see [install-from-source.md](docs/install-from-source.md).

For `etcd` to be on the `PATH`, vfox has to be hooked into your shell, see its [quick start](https://vfox.dev/guides/quick-start.html). `vfox use -g` selects a version for every new shell, and `vfox use` only for the current one.

The versions, and how to pick one, are described in [docs/versions.md](docs/versions.md). Supported platforms are in [docs/platforms.md](docs/platforms.md).

## Use with mise

[vfox](https://github.com/version-fox/vfox) is the recommended plugin system for [mise](https://mise.jdx.dev/). You can use this plugin directly with mise via the `vfox:` prefix.

```shell
# install etcd & set as global version
mise use -g vfox:version-fox/vfox-etcd@latest

# or install a specific version
mise use -g vfox:version-fox/vfox-etcd@3.5.12

# install for local project (creates .mise.toml)
mise use vfox:version-fox/vfox-etcd@3.5.12
```

This sets the version in `~/.config/mise/config.toml`:

```toml
[tools]
"vfox:version-fox/vfox-etcd" = "latest"
```

### Simplify with alias

Add an alias to your `~/.config/mise/config.toml` to use `etcd` as the short name:

```toml
[alias]
etcd = "vfox:version-fox/vfox-etcd"
```

After that, you can use the simplified syntax:

```shell
mise use -g etcd@latest
mise install etcd@3.5.12
```

## Use an etcd that is already installed

If etcd is already on the machine, from a package manager, Homebrew, Scoop or a manual install, `vfox link --detect etcd` adopts it instead of downloading another copy. It needs vfox 1.1.0 or later:

```bash
vfox link --detect etcd
```

The linked version is named after the installation, such as `3.5.12-system` or `3.5.12-brew`, and `vfox use` selects it like any other version. See [docs/link.md](docs/link.md) for where the plugin looks, how the names are built and how to link a directory by hand.

## etcd with failpoints

For the [chaos testing](https://testsigma.com/blog/chaos-testing/) proposal, the plugin can build etcd from source with failpoints. It works on Linux and macOS only, and needs Git, Go and GNU Make:

```shell
# install etcd with failpoint
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.12

vfox use -g etcd@3.5.12
# start etcd with failpoint
GOFAIL_HTTP="127.0.0.1:22381" etcd

# get all failpoint
curl http://127.0.0.1:22381
```

See [docs/failpoint.md](docs/failpoint.md) for what the build does and what it needs.

## Documentation

- [Versions](docs/versions.md): searching, installing, selecting and removing versions
- [Platforms](docs/platforms.md): which operating systems and CPUs have builds
- [Failpoints](docs/failpoint.md): building etcd with `BUILD_WITH_FAILPOINT=yes`
- [Installed etcd](docs/link.md): adopting an etcd on the machine with `vfox link --detect etcd`
- [Troubleshooting](docs/troubleshooting.md): the messages the plugin prints and what to do about them
- [Changes](docs/changes.md): what each release changed
- [Development](docs/development.md): how the plugin is built, checked and released
- [E2E tests](docs/e2e.md): the suites that install the plugin on Linux, macOS and Windows

## Documentation website

[中文](https://version-fox.github.io/vfox-etcd/) · [English](https://version-fox.github.io/vfox-etcd/en/)

The bilingual site is maintained under `website/`. See [website/README.md](website/README.md) for local build and deployment instructions.

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract.

## Contributing

Read [docs/development.md](docs/development.md) before you open a pull request. It lists the checks CI runs, and what to update in `docs/changes.md`, `README.md` and `README_CN.md`.

## License

Apache License 2.0, see [LICENSE](LICENSE).
