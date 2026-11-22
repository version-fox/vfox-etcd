# Use an etcd that is already installed

[中文](zh-CN/link.md) | [English](link.md)

If etcd is already on the machine, `vfox link --detect etcd` adopts it instead of downloading another copy. It needs vfox 1.1.0 or later (`vfox --version`):

```bash
vfox link --detect etcd
```

vfox lists what the plugin found and asks which ones to link. Use `-y` to link all of them without asking:

```bash
vfox link --detect etcd -y
```

A linked version is a symlink to the installation. Nothing is copied, the installation stays where it is and stays its owner's, and `vfox uninstall` removes only the link. `vfox list etcd` marks linked versions.

## Where it looks

The plugin checks every directory on `PATH` first, then the usual places for each system. A directory counts when it holds an `etcd` binary (`etcd.exe` on Windows) that prints its version for `--version`, such as `etcd Version: 3.5.12` or the tag `v0.3.0`.

| Source | Where the plugin looks | Name suffix |
| --- | --- | --- |
| `PATH` | Every directory on `PATH` | by location, as below |
| Linux and macOS | `/usr/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, `/home/linuxbrew/.linuxbrew/bin` | `-system`, `-local`, `-brew` |
| Windows | `%ProgramFiles%\etcd`, `%ProgramFiles(x86)%\etcd` | `-system` |
| Scoop | `%USERPROFILE%\scoop\apps\etcd\current` | `-scoop` |

For a directory on `PATH`, or one of the places above, the suffix comes from where it is:

- `-system` under `/usr` and on Windows under Program Files,
- `-local` under `/usr/local`,
- `-brew` under a Homebrew or Cellar directory,
- `-opt` under `/opt`,
- `-scoop` under a Scoop directory,
- `-path` anywhere else.

## Names

The name is `<version>-<source>`, such as `3.5.12-system` or `3.8.0-alpha.0-brew`. `vfox use` selects a linked version by that name:

```bash
vfox use -g etcd@3.5.12-system
```

If two installations would get the same name, the first one found wins, and `PATH` comes before the fixed directories. An installation from a different source gets a different name: the same version under `/usr/bin` and under `/usr/local/bin` gets `3.5.12-system` and `3.5.12-local`. Two copies from the same source, such as two directories on `PATH`, both get `3.5.12-path`, and only the first is listed.

## What is left out

The plugin skips:

- vfox's own installations, which are the ones under `VFOX_HOME/sdks/etcd` and `VFOX_HOME/cache/etcd` (by default `~/.vfox/sdks/etcd` and `~/.vfox/cache/etcd`),
- shim directories, such as the ones version managers put on `PATH`, because a shim only forwards to an installation somewhere else,
- a binary that does not print an etcd version,
- a directory that is already listed.

## Link a directory by hand

When `--detect` does not find an installation, link it yourself. The path is the directory that contains `bin` (with `etcd` in it), or the directory that holds `etcd` or `etcd.exe` at its root:

```bash
vfox link etcd@3.5.12-system /usr
vfox use -g etcd@3.5.12-system
```

A name that is already linked can be pointed somewhere else with `--force`:

```bash
vfox link --force etcd@3.5.12-system /usr/local
```

`--force` never replaces a version vfox installed. Uninstall that version first.

## System installations

An etcd from a package manager is maintained by that package manager. A linked version follows the installation, so after an upgrade of the system package its reported version changes. Run `vfox link --detect etcd` again to get a name for the new version.
