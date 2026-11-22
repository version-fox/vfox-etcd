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

-- A release without a gofail target has no failpoint build. PreInstall refuses it before anything is cloned, and names
-- the first release that has the target: 3.5.5 has none, and the 3.5 line starts at 3.5.12.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

-- The build tools are reported as present, so only the version can stop the install.
etcd_utils.has_command = function()
    return true
end

local requests = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
    http = function(request)
        table.insert(requests, request.url)
        if request.url == "https://github.com/etcd-io/etcd/releases/tag/v3.5.12" then
            return { status_code = 200, body = "", headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.5" })
end)
assert(not ok and string.find(tostring(err), "etcd 3.5.5 has no failpoint build", 1, true), tostring(err))
assert(string.find(tostring(err), "starts at etcd 3.5.12", 1, true), tostring(err))
assert(#requests == 0, "a release without a failpoint build is refused before any request")

-- The first release of its line that has the target is accepted, and only its release page is read.
requests = {}
local info = plugin:PreInstall({ version = "3.5.12" })
assert(info.version == "3.5.12", tostring(info.version))
assert(
    #requests == 1 and requests[1] == "https://github.com/etcd-io/etcd/releases/tag/v3.5.12",
    table.concat(requests, " ")
)
