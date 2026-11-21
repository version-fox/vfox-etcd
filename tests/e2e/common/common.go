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

// Package common holds the helpers shared by the E2E suites: building the plugin
// archive, installing a pinned vfox, running host commands and small assertions.
// The scenarios live in the per-platform packages, so the workflow only runs `go test`.
package common

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"io/fs"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"testing"
	"time"
)

// VfoxVersion is the vfox release that the suites install. Its archives are pinned
// below with the SHA-256 that the release's checksums.txt publishes.
const VfoxVersion = "1.1.0"

// vfoxRelease is one vfox archive for one platform.
type vfoxRelease struct {
	url    string
	sha256 string
	binary string // the executable's file name inside the archive
}

var vfoxReleases = map[string]vfoxRelease{
	"linux/amd64": {
		url:    "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_linux_x86_64.tar.gz",
		sha256: "3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4",
		binary: "vfox",
	},
	"darwin/amd64": {
		url:    "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_macos_x86_64.tar.gz",
		sha256: "ac4bcda2224a0f8aedf35e3ae22454dc97cf79b69899f43ef6519255a0feb7f6",
		binary: "vfox",
	},
	"darwin/arm64": {
		url:    "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_macos_aarch64.tar.gz",
		sha256: "9beb733ad636966c6d410c768407c63ffb350106eb23a8151d6fc80b9e84248e",
		binary: "vfox",
	},
	"windows/amd64": {
		url:    "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_windows_x86_64.zip",
		sha256: "1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a",
		binary: "vfox.exe",
	},
}

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)

// RepoRoot resolves the repository root from a test in tests/e2e/<suite>.
func RepoRoot(t testing.TB) string {
	t.Helper()
	root, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("resolve repository root: %v", err)
	}
	return root
}

// BuildPluginZip packages the plugin the way `vfox add --source` expects: metadata.lua,
// hooks/ and lib/, with paths relative to the repository root.
func BuildPluginZip(t testing.TB, repoRoot string) string {
	t.Helper()
	dest := filepath.Join(t.TempDir(), "etcd-plugin.zip")
	if err := writePluginZip(dest, repoRoot); err != nil {
		t.Fatalf("build plugin zip: %v", err)
	}
	return dest
}

func writePluginZip(dest, repoRoot string) (err error) {
	file, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := file.Close(); err == nil {
			err = closeErr
		}
	}()
	writer := zip.NewWriter(file)
	for _, name := range []string{"metadata.lua", "hooks", "lib"} {
		root := filepath.Join(repoRoot, name)
		walkErr := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
			if err != nil || entry.IsDir() {
				return err
			}
			relative, err := filepath.Rel(repoRoot, path)
			if err != nil {
				return err
			}
			return addZipFile(writer, path, filepath.ToSlash(relative))
		})
		if walkErr != nil {
			_ = writer.Close()
			return walkErr
		}
	}
	return writer.Close()
}

func addZipFile(writer *zip.Writer, path, name string) error {
	out, err := writer.Create(name)
	if err != nil {
		return err
	}
	in, err := os.Open(path)
	if err != nil {
		return err
	}
	defer in.Close()
	_, err = io.Copy(out, in)
	return err
}

// InstallVfox downloads the pinned vfox release for this platform, verifies its checksum
// and places the executable in <home>/bin. It returns that bin directory.
func InstallVfox(t testing.TB, home string) string {
	t.Helper()
	key := runtime.GOOS + "/" + runtime.GOARCH
	release, ok := vfoxReleases[key]
	if !ok {
		t.Fatalf("no pinned vfox release for %s", key)
	}
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatalf("create vfox bin directory: %v", err)
	}

	archive := filepath.Join(t.TempDir(), filepath.Base(release.url))
	download(t, release.url, archive)
	verifySHA256(t, archive, release.sha256)

	dest := filepath.Join(bin, release.binary)
	if strings.HasSuffix(release.url, ".zip") {
		extractZip(t, archive, release.binary, dest)
	} else {
		extractTar(t, archive, release.binary, dest)
	}
	if err := os.Chmod(dest, 0o755); err != nil {
		t.Fatalf("make vfox executable: %v", err)
	}
	return bin
}

func download(t testing.TB, url, dest string) {
	t.Helper()
	client := &http.Client{Timeout: 5 * time.Minute}
	response, err := client.Get(url)
	if err != nil {
		t.Fatalf("download %s: %v", url, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("download %s: HTTP %d", url, response.StatusCode)
	}
	file, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create %s: %v", dest, err)
	}
	defer file.Close()
	if _, err := io.Copy(file, response.Body); err != nil {
		t.Fatalf("write %s: %v", dest, err)
	}
}

func verifySHA256(t testing.TB, path, want string) {
	t.Helper()
	got, err := fileSHA256(path)
	if err != nil {
		t.Fatalf("hash %s: %v", path, err)
	}
	if got != want {
		t.Fatalf("checksum mismatch for %s: got %s, want %s", path, got, want)
	}
}

func fileSHA256(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func extractTar(t testing.TB, archive, baseName, dest string) {
	t.Helper()
	file, err := os.Open(archive)
	if err != nil {
		t.Fatalf("open %s: %v", archive, err)
	}
	defer file.Close()
	gzipReader, err := gzip.NewReader(file)
	if err != nil {
		t.Fatalf("open gzip %s: %v", archive, err)
	}
	defer gzipReader.Close()
	reader := tar.NewReader(gzipReader)
	for {
		header, err := reader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("read %s: %v", archive, err)
		}
		if header.Typeflag != tar.TypeReg || filepath.Base(header.Name) != baseName {
			continue
		}
		writeReader(t, dest, reader)
		return
	}
	t.Fatalf("%s not found in %s", baseName, archive)
}

func extractZip(t testing.TB, archive, baseName, dest string) {
	t.Helper()
	reader, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatalf("open %s: %v", archive, err)
	}
	defer reader.Close()
	for _, file := range reader.File {
		if file.FileInfo().IsDir() || filepath.Base(file.Name) != baseName {
			continue
		}
		in, err := file.Open()
		if err != nil {
			t.Fatalf("open %s in %s: %v", file.Name, archive, err)
		}
		writeReader(t, dest, in)
		_ = in.Close()
		return
	}
	t.Fatalf("%s not found in %s", baseName, archive)
}

func writeReader(t testing.TB, dest string, reader io.Reader) {
	t.Helper()
	file, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create %s: %v", dest, err)
	}
	defer file.Close()
	if _, err := io.Copy(file, reader); err != nil {
		t.Fatalf("write %s: %v", dest, err)
	}
}

// HomeEnv returns the environment of a test that owns a vfox home. HOME and USERPROFILE
// point into home as well, because vfox keeps its temporary files under the user's home
// and cannot rename them into VFOX_HOME across that boundary. The Go build cache and the
// module cache stay where they are, so a failpoint build does not start from nothing.
// GOBIN points into home, so gofail, which a failpoint build installs, goes away with it.
func HomeEnv(home, bin string) map[string]string {
	env := map[string]string{
		"HOME":        home,
		"USERPROFILE": home,
		"VFOX_HOME":   filepath.Join(home, ".vfox"),
		"GOBIN":       filepath.Join(home, "gobin"),
		"PATH":        bin + string(os.PathListSeparator) + os.Getenv("PATH"),
	}
	if cache, err := os.UserCacheDir(); err == nil {
		env["GOCACHE"] = filepath.Join(cache, "go-build")
	}
	if gopath := goPath(); gopath != "" {
		env["GOPATH"] = gopath
	}
	return env
}

// goPath returns the GOPATH of the host, which holds the module cache, or "" when none is known.
func goPath() string {
	if gopath := os.Getenv("GOPATH"); gopath != "" {
		return gopath
	}
	if output, err := exec.Command("go", "env", "GOPATH").Output(); err == nil {
		if gopath := strings.TrimSpace(string(output)); gopath != "" {
			return gopath
		}
	}
	if realHome, err := os.UserHomeDir(); err == nil {
		return filepath.Join(realHome, "go")
	}
	return ""
}

// Run executes a command in dir with env overlaid on the current environment and
// returns its combined output.
func Run(dir string, env map[string]string, name string, args ...string) (string, error) {
	command := exec.Command(name, args...)
	command.Dir = dir
	command.Env = MergeEnv(env)
	output, err := command.CombinedOutput()
	return string(output), err
}

// RunOK is Run, failing the test on a non-zero exit.
func RunOK(t testing.TB, dir string, env map[string]string, name string, args ...string) string {
	t.Helper()
	output, err := Run(dir, env, name, args...)
	if err != nil {
		t.Fatalf("%s %s failed: %v\n--- output ---\n%s", name, strings.Join(args, " "), err, output)
	}
	return output
}

// RunShell runs a script with bash on Unix and PowerShell on Windows.
func RunShell(dir string, env map[string]string, script string) (string, error) {
	if runtime.GOOS == "windows" {
		return Run(dir, env, "pwsh", "-NoProfile", "-Command", script)
	}
	return Run(dir, env, "bash", "-c", script)
}

// RunShellOK is RunShell, failing the test on a non-zero exit.
func RunShellOK(t testing.TB, dir string, env map[string]string, script string) string {
	t.Helper()
	output, err := RunShell(dir, env, script)
	if err != nil {
		t.Fatalf("shell script failed: %v\n--- script ---\n%s\n--- output ---\n%s", err, script, output)
	}
	return output
}

// MergeEnv overlays extra on the current environment. Windows keys are
// case-insensitive, so PATH replaces Path instead of appearing twice.
func MergeEnv(extra map[string]string) []string {
	values := map[string]string{}
	keyFor := func(key string) string {
		if runtime.GOOS == "windows" {
			return strings.ToUpper(key)
		}
		return key
	}
	for _, item := range os.Environ() {
		key, value, found := strings.Cut(item, "=")
		if !found {
			continue
		}
		values[keyFor(key)] = key + "=" + value
	}
	for key, value := range extra {
		values[keyFor(key)] = key + "=" + value
	}
	result := make([]string, 0, len(values))
	for _, item := range values {
		result = append(result, item)
	}
	return result
}

// StripANSI removes terminal colour codes from command output.
func StripANSI(value string) string {
	return ansi.ReplaceAllString(value, "")
}

// RequireContains fails the test unless output contains want once colour codes are removed.
func RequireContains(t testing.TB, output, want, label string) {
	t.Helper()
	if !strings.Contains(StripANSI(output), want) {
		t.Fatalf("%s: missing %q\n--- output ---\n%s", label, want, output)
	}
}

// BashQuote quotes value for a POSIX shell.
func BashQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", `'\''`) + "'"
}

// PowerShellQuote quotes value for PowerShell.
func PowerShellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "''") + "'"
}
