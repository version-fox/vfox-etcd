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
-- The 3.4 line enables the failpoints with gofail-enable instead.
assert(string.find(command, "grep -q '^gofail-enable:' Makefile", 1, true), command)
assert(string.find(command, "make gofail-enable", 1, true), command)
assert(
    not pcall(etcd_utils.failpoint_build_command, "/tmp", "3.4.32; rm -rf /"),
    "a non-release must not reach the shell"
)
