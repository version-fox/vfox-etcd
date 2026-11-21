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

package common

import (
	"archive/zip"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func TestQuotes(t *testing.T) {
	if got := BashQuote("/opt/my tools/it's"); got != `'/opt/my tools/it'\''s'` {
		t.Fatalf("BashQuote: %s", got)
	}
	if got := PowerShellQuote("C:\\Program Files\\it's"); got != `'C:\Program Files\it''s'` {
		t.Fatalf("PowerShellQuote: %s", got)
	}
}

func TestStripANSI(t *testing.T) {
	if got := StripANSI("\x1b[32metcd\x1b[0m 3.5.12"); got != "etcd 3.5.12" {
		t.Fatalf("StripANSI: %q", got)
	}
}

func TestPluginZipHoldsOnlyThePlugin(t *testing.T) {
	repo := t.TempDir()
	files := map[string]string{
		"metadata.lua":       "PLUGIN = {}",
		"hooks/pre.lua":      "-- hook",
		"lib/etcd_utils.lua": "-- lib",
		"docs/changes.md":    "not part of the plugin",
		"tests/x_test.lua":   "not part of the plugin",
	}
	for name, body := range files {
		path := filepath.Join(repo, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	dest := filepath.Join(t.TempDir(), "plugin.zip")
	if err := writePluginZip(dest, repo); err != nil {
		t.Fatalf("writePluginZip: %v", err)
	}
	reader, err := zip.OpenReader(dest)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	var names []string
	for _, file := range reader.File {
		names = append(names, file.Name)
	}
	sort.Strings(names)
	want := []string{"hooks/pre.lua", "lib/etcd_utils.lua", "metadata.lua"}
	if strings.Join(names, ",") != strings.Join(want, ",") {
		t.Fatalf("zip entries %v, want %v", names, want)
	}
}

func TestMergeEnvOverlays(t *testing.T) {
	t.Setenv("VFOX_TEST_MARKER", "from-process")
	merged := MergeEnv(map[string]string{"VFOX_TEST_MARKER": "from-test"})
	count := 0
	for _, item := range merged {
		if strings.HasPrefix(strings.ToUpper(item), "VFOX_TEST_MARKER=") {
			count++
			if !strings.HasSuffix(item, "=from-test") {
				t.Fatalf("overlay lost: %s", item)
			}
		}
	}
	if count != 1 {
		t.Fatalf("VFOX_TEST_MARKER appears %d times", count)
	}
}
