-- Copyright 2026 version-fox and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Copyright 2026 version-fox and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Pure helpers of lib/etcd_utils.lua. They take the platform as arguments, so no plugin is loaded.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
test.load({ os = "linux", arch = "amd64", env = {} })
local etcd_utils = require("etcd_utils")

for _, version in ipairs({ "3.5.12", "3.4.32", "3.8.0-alpha.0", "3.5.0-rc.1" }) do
    assert(etcd_utils.is_valid_version(version), "should accept " .. version)
end
for _, version in ipairs({ "", "3.5", "v3.5.12", "3.5.12 ", "latest", "3.5.12; rm -rf ~", "3.5.12$(id)" }) do
    assert(not etcd_utils.is_valid_version(version), "should reject " .. version)
end

assert(etcd_utils.archive_name("3.5.12", "linux", "amd64") == "etcd-v3.5.12-linux-amd64.tar.gz")
assert(etcd_utils.archive_name("3.5.12", "linux", "arm64") == "etcd-v3.5.12-linux-arm64.tar.gz")
assert(etcd_utils.archive_name("3.5.12", "darwin", "arm64") == "etcd-v3.5.12-darwin-arm64.zip")
assert(etcd_utils.archive_name("3.5.12", "windows", "amd64") == "etcd-v3.5.12-windows-amd64.zip")

assert(etcd_utils.parse_version("etcd Version: 3.5.12\nGit SHA: 9e2c\nGo OS/Arch: linux/amd64\n") == "3.5.12")
assert(etcd_utils.parse_version("etcd Version: 3.8.0-alpha.0\r\n") == "3.8.0-alpha.0")
assert(etcd_utils.parse_version("etcd Version: banana\n") == nil)
assert(etcd_utils.parse_version("sh: etcd: not found\n") == nil)
-- Release 0.3.0 prints only its tag. Output with a tag and anything else is not that release.
assert(etcd_utils.parse_version("v0.3.0\n") == "0.3.0")
assert(etcd_utils.parse_version("v0.5.0-alpha.0\r\n") == "0.5.0-alpha.0")
assert(etcd_utils.parse_version("vfox 1.1.0\n") == nil)
assert(etcd_utils.parse_version("v3.5\n") == nil)
assert(etcd_utils.parse_version("v0.3.0\nextra line\n") == nil)

assert(etcd_utils.shell_quote("/opt/my tools") == "'/opt/my tools'")
assert(etcd_utils.shell_quote("it's") == "'it'\\''s'")
assert(etcd_utils.trim("  3.5.12\r ") == "3.5.12")
assert(not etcd_utils.file_exists("/nonexistent/vfox-etcd-test/etcd"))

local command = etcd_utils.failpoint_build_command("/home/me/.vfox/sdks/etcd/v-3.5.12", "3.5.12")
assert(string.find(command, "cd '/home/me/.vfox/sdks/etcd/v-3.5.12' && git clone", 1, true), command)
assert(string.find(command, "--depth 1 --branch v3.5.12 https://github.com/etcd-io/etcd.git etcd", 1, true), command)
-- gofail must be on PATH before the make targets look for it, and the build needs FAILPOINTS=true.
local path_at = string.find(command, 'export PATH="$(go env GOBIN | grep . || echo "$(go env GOPATH', 1, true)
local install_at = string.find(command, "make install-gofail", 1, true)
local build_at = string.find(command, "FAILPOINTS=true make build", 1, true)
assert(path_at and install_at and build_at, command)
assert(path_at < install_at and install_at < build_at, command)
-- A gofail-enable target is found with make -q, wherever the Makefile defines it. Grepping the root Makefile missed
-- the target of 3.6, which that Makefile includes.
assert(
    string.find(
        command,
        "if make -q gofail-enable >/dev/null 2>&1 || [ $? -eq 1 ]; then make gofail-enable; else make install-gofail; fi",
        1,
        true
    ),
    command
)
assert(
    not pcall(etcd_utils.failpoint_build_command, "/tmp", "3.4.32; rm -rf /"),
    "a non-release must not reach the shell"
)

-- Releases before CHECKSUMS_FROM are the ones whose archives are pinned; 3.4.0 and later must publish a checksum.
for _, version in ipairs({ "0.2.0-rc4", "2.3.8", "3.2.30", "3.3.13", "3.4.0-rc.1" }) do
    assert(etcd_utils.is_before_checksums(version), "should be before 3.4.0: " .. version)
end
for _, version in ipairs({ "3.4.0", "3.4.1", "3.5.0-alpha.0", "3.5.12" }) do
    assert(not etcd_utils.is_before_checksums(version), "should not be before 3.4.0: " .. version)
end
assert(string.find(etcd_utils.pinned_notice("3.3.13", "etcd-v3.3.13-linux-amd64.tar.gz"), "pinned", 1, true))

-- The version list is read from the release tag of the plugin, never from the default branch.
assert(
    etcd_utils.versions_url("0.2.1")
        == "https://fastly.jsdelivr.net/gh/version-fox/vfox-etcd@v0.2.1/assets/versions.txt",
    etcd_utils.versions_url("0.2.1")
)
for _, version in ipairs({ "", "0.2", "v0.2.1", "0.2.1-rc.1", "0.2.1@main" }) do
    assert(not pcall(etcd_utils.versions_url, version), "should refuse plugin version " .. version)
end
assert(not pcall(etcd_utils.versions_url, nil), "should refuse a missing plugin version")

-- BUILD_WITH_FAILPOINT turns the failpoint build on with yes only. Other values are refused, not ignored.
assert(etcd_utils.failpoint_requested(nil) == false)
assert(etcd_utils.failpoint_requested("") == false)
assert(etcd_utils.failpoint_requested("no") == false)
assert(etcd_utils.failpoint_requested("yes") == true)
for _, value in ipairs({ "1", "true", "YES", "yes " }) do
    local ok, err = pcall(etcd_utils.failpoint_requested, value)
    assert(not ok and string.find(tostring(err), "BUILD_WITH_FAILPOINT is", 1, true), "should refuse " .. value)
end

-- A failpoint build needs git, go and make on PATH. The missing ones are named, in their order.
local present = {}
etcd_utils.has_command = function(name)
    return present[name] == true
end
present = { git = true, go = true, make = true }
assert(#etcd_utils.missing_build_tools() == 0)
present = { git = true, make = true }
assert(table.concat(etcd_utils.missing_build_tools(), ",") == "go")
present = {}
assert(table.concat(etcd_utils.missing_build_tools(), ",") == "git,go,make")

-- The binary of a failpoint build links the gofail runtime. The check reads the file, and a missing file has none.
local function write_file(content)
    local path = os.tmpname()
    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
    return path
end
local with_failpoints = write_file("binary with go.etcd.io/gofail/runtime.Eval inside")
local official = write_file("binary of the official build")
assert(etcd_utils.has_failpoints(with_failpoints))
assert(not etcd_utils.has_failpoints(official))
assert(not etcd_utils.has_failpoints("/nonexistent/vfox-etcd-test/etcd"))
os.remove(with_failpoints)
os.remove(official)
