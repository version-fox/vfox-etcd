<div align="center">

![logo](./assets/vfox-etcd-logo.png)

[![E2E tests](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml)

</div>

# vfox-etcd plugin

etcd [vfox](https://github.com/version-fox) plugin. Use the vfox to manage multiple [etcd](https://etcd.io/) & etcdctl & etcductl versions in Linux/Darwin MacOS/Windows. Also can be used to build etcd with [failpoint](https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally).

## Usage

### vfox

```shell
# install plugin
vfox add --source https://github.com/version-fox/vfox-etcd/archive/refs/heads/main.zip etcd

# install an available etcd version
vfox search etcd
# or specific version 
vfox install etcd@3.5.5
```

### mise

[vfox](https://github.com/version-fox/vfox) is the recommended plugin system for [mise](https://mise.jdx.dev/). You can use this plugin directly with mise via the `vfox:` prefix.

```shell
# install etcd & set as global version
mise use -g vfox:version-fox/vfox-etcd@latest

# or install a specific version
mise use -g vfox:version-fox/vfox-etcd@3.5.5

# install for local project (creates .mise.toml)
mise use vfox:version-fox/vfox-etcd@3.5.5
```

This sets the version in `~/.config/mise/config.toml`:

```toml
[tools]
"vfox:version-fox/vfox-etcd" = "latest"
```

#### Simplify with alias

Add an alias to your `~/.config/mise/config.toml` to use `etcd` as the short name:

```toml
[alias]
etcd = "vfox:version-fox/vfox-etcd"
```

After that, you can use the simplified syntax:

```shell
mise use -g etcd@latest
mise install etcd@3.5.5
```

### etcd with failpoint (Only support in Unix-like OS system)

For the [chaos testing](https://testsigma.com/blog/chaos-testing/) proposal, you can also utilize vfox-etcd to build etcd with failpoint. Example:

**Requirements:**

- [Go 1.21+](https://go.dev/)
- [GNU Make](https://www.gnu.org/software/make/)

```shell
# install etcd with failpoint
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.5

vfox use etcd@3.5.5
# start etcd with failpoint
GOFAIL_HTTP="127.0.0.1:22381" etcd

# get all failpoint
curl http://127.0.0.1:22381
```
