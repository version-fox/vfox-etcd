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

//go:build linux

// Package linux runs the plugin in a bare Ubuntu container, built from Dockerfile and
// discarded after each scenario, so the results do not depend on the host's tools.
package linux

import (
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/version-fox/vfox-etcd/tests/e2e/common"
)

const image = "vfox-etcd-e2e:linux"

// TestContainerE2E runs each scenario in a fresh container from tests/e2e/linux/Dockerfile.
// The image has vfox and curl but no build packages, so the archive install is proven to
// need none. It is skipped under -short, and when Docker is not installed.
func TestContainerE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the container suite builds an image and needs Docker")
	}
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker is not installed")
	}
	repoRoot := common.RepoRoot(t)
	buildImage(t, repoRoot)
	plugin := common.BuildPluginZip(t, repoRoot)

	t.Run("archive install without build packages", func(t *testing.T) {
		output := runContainer(t, repoRoot, plugin, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox add --source /tmp/etcd-plugin.zip
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
eval "$(vfox activate bash)"
etcd --version
etcdctl version
etcdutl version
`)
		common.RequireContains(t, output, "etcd Version: 3.5.12", "etcd")
		common.RequireContains(t, output, "etcdctl version: 3.5.12", "etcdctl")
		common.RequireContains(t, output, "etcdutl version: 3.5.12", "etcdutl")
	})

	t.Run("system install detected in the container", func(t *testing.T) {
		output := runContainer(t, repoRoot, plugin, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox add --source /tmp/etcd-plugin.zip
vfox install etcd@3.5.12
vfox use -g etcd@3.5.12
eval "$(vfox activate bash)"
mkdir -p /opt/etcd-system/bin
cp "$(command -v etcd)" "$(command -v etcdctl)" "$(command -v etcdutl)" /opt/etcd-system/bin/
export PATH=/opt/etcd-system/bin:$PATH
vfox link --detect etcd -y
vfox use -g etcd@3.5.12-opt
eval "$(vfox activate bash)"
echo "linked etcd: $(command -v etcd)"
etcd --version
`)
		common.RequireContains(t, output, "3.5.12-opt", "detection names the install by its location")
		common.RequireContains(t, output, "etcd Version: 3.5.12", "the linked etcd runs")
	})
}

// buildImage builds the image from the Dockerfile, with an empty build context.
func buildImage(t *testing.T, repoRoot string) {
	t.Helper()
	context := t.TempDir()
	common.RunOK(t, repoRoot, nil, "docker", "build",
		"--tag", image,
		"--file", filepath.Join(repoRoot, "tests", "e2e", "linux", "Dockerfile"),
		context)
}

// runContainer runs script in a new container with the plugin archive mounted read-only.
func runContainer(t *testing.T, repoRoot, plugin, script string) string {
	t.Helper()
	return common.RunOK(t, repoRoot, nil, "docker", "run", "--rm",
		"--volume", plugin+":/tmp/etcd-plugin.zip:ro",
		image, "bash", "-c", script)
}
