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

-- PostInstall builds the release tag of the installed version, fails when the build fails, and fails when the binary
-- it built links no gofail runtime.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

local executed = {}
local next_status = 0
os.execute = function(command)
    table.insert(executed, command)
    return next_status
end

-- The check of the binary is replaced, because a plugin test has no build to read. has_failpoints says what it finds.
local checked = {}
local has_failpoints = true
etcd_utils.has_failpoints = function(path)
    table.insert(checked, path)
    return has_failpoints
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
})

local ctx = {
    sdkInfo = {
        etcd = { path = "/home/me/.vfox/sdks/etcd/v-3.4.32", version = "3.4.32", name = "etcd" },
    },
}
plugin:PostInstall(ctx)
assert(#executed == 1, "one build command")
assert(
    string.find(executed[1], "git clone --depth 1 --branch v3.4.32 https://github.com/etcd-io/etcd.git etcd", 1, true),
    executed[1]
)
assert(checked[1] == "/home/me/.vfox/sdks/etcd/v-3.4.32/etcd/bin/etcd", tostring(checked[1]))

-- A path with a space is quoted, so the build still runs in the install directory.
executed = {}
plugin:PostInstall({
    sdkInfo = {
        etcd = { path = "/home/me/my sdks/etcd/v-3.5.12", version = "3.5.12", name = "etcd" },
    },
})
assert(#executed == 1, "one build command")
assert(string.find(executed[1], "cd '/home/me/my sdks/etcd/v-3.5.12' && git clone", 1, true), executed[1])

-- A build that finishes without the gofail runtime is an error, and the message names the binary.
has_failpoints = false
local ok, err = pcall(function()
    plugin:PostInstall(ctx)
end)
assert(not ok and string.find(tostring(err), "built without failpoints", 1, true), tostring(err))
assert(string.find(tostring(err), "/home/me/.vfox/sdks/etcd/v-3.4.32/etcd/bin/etcd", 1, true), tostring(err))
has_failpoints = true

next_status = 2
ok, err = pcall(function()
    plugin:PostInstall(ctx)
end)
assert(not ok and string.find(tostring(err), "failpoint failed", 1, true), tostring(err))
