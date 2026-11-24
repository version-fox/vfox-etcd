# Install from source

[中文](zh-CN/install-from-source.md) | [English](install-from-source.md)

`vfox add etcd` only adds the plugin. `vfox install etcd@latest` installs the latest release. To try `main`, a branch, or a change you are working on, build the plugin from source. A plugin is a `metadata.lua` plus the `hooks` and `lib` directories, and vfox adds one from a zip of them.

## Ubuntu and macOS

On Ubuntu, install `git` and `zip` first. macOS has both. Execute in Bash,

```bash
sudo apt install --assume-yes git zip
git clone --depth 1 https://github.com/version-fox/vfox-etcd.git
cd ./vfox-etcd/
zip -qr ./etcd.zip metadata.lua hooks lib
vfox add etcd --source ./etcd.zip
rm ./etcd.zip
```

To try a branch, clone that branch instead:

```bash
git clone --depth 1 --branch <branch> https://github.com/version-fox/vfox-etcd.git
```

## Windows 11

Assume that PowerShell 7 is already installed. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
git clone --depth 1 https://github.com/version-fox/vfox-etcd.git
cd ./vfox-etcd/
tar -a -cf ./etcd.zip metadata.lua hooks lib
vfox add etcd --source ./etcd.zip
Remove-Item ./etcd.zip
```

## Check it

```bash
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
etcd --version
```

`etcd --version` prints `etcd Version: 3.5.12` for the example.

## When etcd is already added

`vfox add` refuses with `plugin named etcd already exists`. Either replace the plugin, or add the source build under another name.

To replace it, remove the plugin first. `vfox remove` also removes the etcd versions installed through the plugin, and vfox says so before it asks. Reinstall them afterwards.

```bash
vfox remove -y etcd
vfox add etcd --source ./etcd.zip
```

To keep both, add the source build under another name. The alias is a plugin of its own:

```bash
vfox add etcd --source ./etcd.zip --alias etcd-dev
```

`vfox remove -y etcd-dev` removes that plugin, and only it, with the etcd versions it installed.

## Updating

Pull the source, zip it again, and add the plugin again:

```bash
cd ./vfox-etcd/
git pull
zip -qr ./etcd.zip metadata.lua hooks lib
vfox remove -y etcd
vfox add etcd --source ./etcd.zip
rm ./etcd.zip
```

`vfox update etcd` replaces a source build only when the registry has a newer version than the one in `metadata.lua`. While the versions are equal, it prints `etcd is already the latest version` and keeps the source build.

To work on the plugin, see [development.md](development.md).
