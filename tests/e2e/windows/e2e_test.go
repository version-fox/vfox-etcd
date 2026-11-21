// Copyright 2026 version-fox and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build windows

// Package windows runs the plugin on the Windows host with PowerShell. It covers an
// archive install and a system install adopted with `vfox link --detect`.
package windows

import (
	"path/filepath"
	"testing"

	"github.com/version-fox/vfox-etcd/tests/e2e/common"
)

const pwshPrelude = "$ErrorActionPreference = 'Stop'; $PSNativeCommandUseErrorActionPreference = $true;"

// TestNativeE2E installs the plugin into a fresh vfox home and runs the scenarios.
func TestNativeE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the Windows E2E suite installs vfox and etcd over the network")
	}
	repoRoot := common.RepoRoot(t)
	home := t.TempDir()
	bin := common.InstallVfox(t, home)
	plugin := common.BuildPluginZip(t, repoRoot)
	env := common.HomeEnv(home, bin)

	output := common.RunShellOK(t, repoRoot, env, pwshPrelude+" vfox add --source "+common.PowerShellQuote(plugin))
	common.RequireContains(t, output, "successfully", "vfox add")

	t.Run("archive install", func(t *testing.T) {
		output := common.RunShellOK(t, repoRoot, env, pwshPrelude+`
Invoke-Expression "$(vfox activate pwsh)"
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
Invoke-Expression "$(vfox activate pwsh)"
etcd --version
etcdctl version
etcdutl version
`)
		common.RequireContains(t, output, "etcd Version: 3.5.12", "etcd")
		common.RequireContains(t, output, "etcdctl version: 3.5.12", "etcdctl")
		common.RequireContains(t, output, "etcdutl version: 3.5.12", "etcdutl")
	})

	t.Run("system install detected and used", func(t *testing.T) {
		system := filepath.Join(home, "system", "bin")
		output := common.RunShellOK(t, repoRoot, env, pwshPrelude+`
Invoke-Expression "$(vfox activate pwsh)"
New-Item -ItemType Directory -Force -Path `+common.PowerShellQuote(system)+` | Out-Null
foreach ($tool in @('etcd', 'etcdctl', 'etcdutl')) {
    Copy-Item -Path (Get-Command $tool).Source -Destination `+common.PowerShellQuote(system)+`
}
$env:PATH = `+common.PowerShellQuote(system)+` + ';' + $env:PATH
vfox link --detect etcd -y
vfox use -g etcd@3.5.12-path
Invoke-Expression "$(vfox activate pwsh)"
Write-Output "linked etcd: $((Get-Command etcd).Source)"
etcd --version
`)
		common.RequireContains(t, output, "3.5.12-path", "detection names the install")
		common.RequireContains(t, output, "etcd Version: 3.5.12", "the linked etcd runs")
	})
}
