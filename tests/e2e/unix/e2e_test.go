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

//go:build unix

// Package unix runs the plugin with the vfox that the suite installs, on the host
// itself: Linux and macOS. Windows has its own suite in ../windows.
package unix

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/version-fox/vfox-etcd/tests/e2e/common"
)

// failpointVersion is the release that the failpoint scenario builds from source. It is the
// version that the README uses in its example.
const failpointVersion = "3.5.12"

// TestNativeE2E installs the plugin, then runs the scenarios: an archive install, a system
// install adopted with `vfox link --detect`, and a source build with failpoints. The failpoint
// build compiles etcd, so it is skipped under -short.
func TestNativeE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("the native E2E suite installs vfox and etcd over the network")
	}
	repoRoot := common.RepoRoot(t)
	home := t.TempDir()
	bin := common.InstallVfox(t, home)
	plugin := common.BuildPluginZip(t, repoRoot)
	env := common.HomeEnv(home, bin)

	output := common.RunShellOK(t, repoRoot, env, "vfox add --source "+common.BashQuote(plugin))
	common.RequireContains(t, output, "successfully", "vfox add")

	t.Run("archive install", func(t *testing.T) {
		output := common.RunShellOK(t, repoRoot, env, `
set -euo pipefail
eval "$(vfox activate bash)"
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

	t.Run("system install detected and used", func(t *testing.T) {
		system := filepath.Join(home, "system", "bin")
		output := common.RunShellOK(t, repoRoot, env, `
set -euo pipefail
eval "$(vfox activate bash)"
mkdir -p `+common.BashQuote(system)+`
cp "$(command -v etcd)" "$(command -v etcdctl)" "$(command -v etcdutl)" `+common.BashQuote(system)+`/
export PATH=`+common.BashQuote(system)+`:$PATH
vfox link --detect etcd -y
vfox use -g etcd@3.5.12-path
eval "$(vfox activate bash)"
echo "linked etcd: $(command -v etcd)"
etcd --version
`)
		common.RequireContains(t, output, "3.5.12-path", "detection names the install")
		common.RequireContains(t, output, "etcd Version: 3.5.12", "the linked etcd runs")
	})

	t.Run("failpoint build", func(t *testing.T) {
		// The build has a home of its own. The archive install above already holds etcd 3.5.12,
		// and vfox would keep that one instead of building the same version again.
		failHome := t.TempDir()
		failEnv := common.HomeEnv(failHome, bin)
		failEnv["BUILD_WITH_FAILPOINT"] = "yes"
		// The build runs before vfox is activated. Activation rewrites PATH and drops the directories
		// that belong to vfox, so a Go that vfox manages would be missing from the build's PATH.
		common.RunShellOK(t, repoRoot, failEnv, `
set -euo pipefail
vfox add --source `+common.BashQuote(plugin)+`
vfox install etcd@`+failpointVersion+`
eval "$(vfox activate bash)"
vfox use -g etcd@`+failpointVersion+`
`)
		checkFailpoints(t, repoRoot, failEnv)
	})
}

// syncBuffer collects the output of etcd. exec copies a child's output from its own goroutines,
// so the buffer has to lock.
type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *syncBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

// checkFailpoints starts the failpoint build of etcd and asks its gofail endpoint for the
// failpoints it compiled in, the way the robustness tests do.
func checkFailpoints(t *testing.T, repoRoot string, env map[string]string) {
	t.Helper()
	const endpoint = "http://127.0.0.1:22381"
	version := common.RunShellOK(t, repoRoot, env, `
eval "$(vfox activate bash)"
etcd --version
`)
	// A build with failpoints says so in its Git SHA, as the build script appends -FAILPOINTS.
	common.RequireContains(t, version, "-FAILPOINTS", "the build enables failpoints")
	dataDir := t.TempDir()
	script := fmt.Sprintf(`
eval "$(vfox activate bash)"
export GOFAIL_HTTP=127.0.0.1:22381
exec etcd --name e2e --data-dir %s \
  --listen-client-urls http://127.0.0.1:23790 --advertise-client-urls http://127.0.0.1:23790 \
  --listen-peer-urls http://127.0.0.1:23800 --initial-advertise-peer-urls http://127.0.0.1:23800 \
  --initial-cluster e2e=http://127.0.0.1:23800
`, common.BashQuote(dataDir))

	command := exec.Command("bash", "-c", script)
	command.Dir = repoRoot
	command.Env = common.MergeEnv(env)
	var log syncBuffer
	command.Stdout = &log
	command.Stderr = &log
	if err := command.Start(); err != nil {
		t.Fatalf("start etcd: %v", err)
	}
	defer func() {
		_ = command.Process.Kill()
		_ = command.Wait()
	}()

	// etcd registers its failpoints while it starts, and gofail answers before that is done, so a list read early can
	// lack some of them. Every failpoint is registered once the client port reports healthy, so the list is read only
	// after that, and the check passes only when the list holds afterCommit.
	const clientHealth = "http://127.0.0.1:23790/health"
	deadline := time.Now().Add(90 * time.Second)
	var last string
	for {
		health, healthErr := fetch(clientHealth)
		if healthErr == nil && strings.Contains(health, `"health":"true"`) {
			body, bodyErr := fetch(endpoint)
			if bodyErr == nil && strings.Contains(body, "afterCommit") {
				return
			}
			last = fmt.Sprintf("the failpoint list after etcd reported healthy was %q (%v)", body, bodyErr)
		} else {
			last = fmt.Sprintf("the health check answered %q (%v)", health, healthErr)
		}
		if time.Now().After(deadline) {
			t.Fatalf("etcd did not list its failpoints within 90s: %s\n--- etcd output ---\n%s", last, log.String())
		}
		time.Sleep(time.Second)
	}
}

func fetch(url string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return "", err
	}
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d", response.StatusCode)
	}
	return string(body), nil
}
