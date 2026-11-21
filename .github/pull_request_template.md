## Summary

<!-- What changes, and why. -->

## Checks

- [ ] `stylua --check .` and the Lua diagnostics pass (`lua-language-server --check . --checklevel=Warning`)
- [ ] `vfox plugin test .` passes
- [ ] Python and Go checks pass when those files change (`ruff`, `gofmt`, `go vet`, `go test -short ./...` in `tests/e2e`)
- [ ] Both languages were updated: `README.md` with `README_CN.md`, and `docs/` with `docs/zh-CN/`
- [ ] `docs/changes.md` and `docs/zh-CN/changes.md` have an entry under Unreleased for a user-visible change
- [ ] New or changed Lua, Go and Python files carry the license header
