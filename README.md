<div align="center">

![logo](./assets/vfox-etcd-logo.png)

[![E2E tests](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml/badge.svg)](https://github.com/version-fox/vfox-etcd/actions/workflows/e2e_test.yaml)

</div>

# vfox-etcd plugin

etcd [vfox](https://github.com/version-fox) plugin. Use the vfox to manage multiple [etcd](https://etcd.io/) & etcdctl & etcductl versions in Linux/Darwin MacOS/Windows. Also can be used to build etcd with [failpoint](https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally).

## Usage

```shell
# install plugin
vfox add --source https://github.com/version-fox/vfox-etcd/archive/refs/heads/main.zip etcd

# install an available etcd version
vofx search etcd
# or specific version 
vfox install etcd@3.5.5
```

### etcd with failpoint

For the chaos testing proposal, you can also utilize vfox-etcd to build etcd with failpoint. Example:

```shell
# install etcd with failpoint
BUILD_WITH_FAILPOINT=yes vfox install etcd@3.5.5

vfox use etcd@3.5.5
# start etcd with failpoint
GOFAIL_HTTP="127.0.0.1:22381" etcd

# get all failpoint
curl http://127.0.0.1:22381
```
