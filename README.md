<div align="center">

![logo](./assets/vfox-etcd-logo.png)

[![E2E tests](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml)

</div>

# vfox-etcd plugin

etcd [vfox](https://github.com/version-fox) plugin. Use the vfox to manage multiple [etcd](https://etcd.io/) versions in Linux/Darwin MacOS/Windows.

## Usage

```shell
# install plugin
vfox add --source https://github.com/version-fox/vfox-etcd/archive/refs/heads/main.zip etcd

# install an available version
vofx search etcd
# or specific version 
vfox install etcd@3.5.5
```

### etcd with failpoint

```shell
# install etcd with failpoint
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.5

vfox use etcd@3.5.5
# start etcd with failpoint
GOFAIL_HTTP="127.0.0.1:22381" etcd

# get all failpoint
curl http://127.0.0.1:22381
```
