# Development

[中文](zh-CN/development.md) | [English](development.md)

This page is for people who change the plugin. For using it, see the [README](../README.md).

## Layout

| Path | What it holds |
| --- | --- |
| `metadata.lua` | The plugin name, version and minimum vfox version. The release workflow sets the version. |
| `hooks/` | One file per vfox hook: `available.lua`, `pre_install.lua`, `post_install.lua`, `env_keys.lua`, `pre_use.lua` and `detect.lua`. |
| `lib/` | Helpers the hooks require: `etcd_utils.lua` for downloads, checksums and version strings, and `detect_etcd.lua` for finding installations. |
| `tests/` | `*_test.lua` files, which `vfox plugin test` runs offline, and `tests/e2e`, the Go suites that install the plugin. |
| `assets/` | `versions.txt`, the released versions that `vfox search` shows, and the script that refreshes it. |
| `website/` | The landing pages, in Chinese and English, built by `website/build.py`. |
| `docs/` | This documentation, in English, with the Chinese pages under `docs/zh-CN/`. |
| `.github/` | The workflows, the documentation check and the pull request template. |

## What the hooks do

- `Available` lists the versions in `assets/versions.txt`.
- `PreInstall` checks the version, and returns the archive URL and the checksum from the release's `SHA256SUMS`. With `BUILD_WITH_FAILPOINT=yes` on Linux or macOS, it returns no archive, so the source is built.
- `PostInstall` runs the failpoint build when it is asked for.
- `EnvKeys` puts the binaries on `PATH`. They sit in `bin/` for a linked system install, in `etcd/bin` for a source build, and at the root for an archive.
- `PreUse` refuses a version that is not installed.
- `Detect` scans for etcd installations for `vfox link --detect etcd`. See [link.md](link.md).

## Checks

CI runs these, and a pull request must pass them. Run the ones for the files you changed:

| Check | Command | Where it runs |
| --- | --- | --- |
| Lua format | `stylua --check .` | `lint.yml` |
| Lua diagnostics | `lua-language-server --check . --checklevel=Warning` | `lint.yml` |
| Plugin tests | `vfox plugin test .` (vfox 1.1.0) | `test.yml` |
| Workflow files | `actionlint` | `lint.yml` |
| Python format and lint | `ruff format --check .` and `ruff check .` | `lint.yml` |
| Go format, vet and unit tests | `gofmt -l .`, `go vet ./...` and `go test -short ./...` in `tests/e2e` | `lint.yml` |
| Documentation pairs | `python3 -I .github/scripts/check_docs_parity.py .` | `lint.yml` |
| License headers | `license-eye header check -c .licenserc.yaml` (skywalking-eyes) | `license.yml` |
| End to end | see [e2e.md](e2e.md) | `e2e.yml` |

The tools are pinned: stylua 2.6.0, lua-language-server 3.19.1, actionlint 1.7.12, ruff 0.17.6, vfox 1.1.0 and Go 1.27.1. Change a pin in the workflow that runs the tool, and in this page.

## Tests

`vfox plugin test .` runs each `tests/**/*_test.lua` in a VM of its own, and the rules are these:

- A test file calls `require("vfox.test")` and `test.load(...)` once. `test.load` takes the platform, the environment, and an `http` handler that answers the plugin's requests.
- Helpers in `lib/` are loaded with `require`, after `package.path = "./lib/?.lua;" .. package.path`.
- A test may replace a function it needs, such as `os.execute` or `etcd_utils.file_exists`, before it calls the hook.
- `os.execute` cannot run a real command here, so the build and the directory probes are tested with replacements. The end-to-end suites run the real ones.

## Writing documentation

Every page in `docs/` has a page in `docs/zh-CN/` with the same name, and `README.md` has `README_CN.md`. The documentation check fails when:

- a page has no partner,
- the two pages name different `VFOX_*`, `ETCD_*`, `BUILD_WITH_FAILPOINT` or `GOFAIL_*` variables,
- they have a different number of fenced code blocks,
- a relative link does not resolve.

Translate the sentences, and keep the commands and the code blocks the same. Each page has a language line under its title, with 中文 first on both pages: `[中文](zh-CN/<page>) | [English](<page>)` on an English page, and `[中文](<page>) | [English](../<page>)` on a Chinese page.

## Changes

Every user-visible change adds a line to `docs/changes.md` and to `docs/zh-CN/changes.md`, under `## Unreleased`. Maintainers rename that heading when they release.

## License headers

Every file that can hold a comment carries the Apache 2.0 header with `Copyright 2026 version-fox and contributors`. Among them are the Lua, Go, Python, YAML, TOML and Dockerfile files, and `.gitignore`. The `license.yml` workflow checks it with the configuration in `.licenserc.yaml`. Files that cannot take a comment, such as JSON, Markdown and the official logo, are listed there as ignored.

## Website

The landing pages are built with the standard library only:

```bash
python3 website/build.py --output /tmp/vfox-etcd-site
python3 -m http.server 8080 --directory /tmp/vfox-etcd-site
```

See [website/README.md](../website/README.md) for the deployment.

## Releasing

Maintainers publish from **Actions → Plugin → Run workflow** on the default branch, by entering a stable plugin version without the `v` prefix. The shared workflow updates `metadata.lua`, creates the version commit and tag, and publishes the ZIP and manifest in this repository. No local tag or extra release token is needed. Pull requests run checks only.

Existing version-tag pushes are supported when `PLUGIN.version` already matches the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action) for the package contract.

## Versions list

`assets/versions.txt` is refreshed by the `update_etcd_versions` workflow every Monday. It reads the etcd tags with the GitHub API, and fails, without touching the list, when the API cannot be reached. To refresh it by hand, run it from the `assets` directory with a token in `GITHUB_TOKEN`:

```bash
cd assets && python3 -m pip install requests packaging && python3 get_all_etcd_versions.py
```
