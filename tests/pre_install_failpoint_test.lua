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

-- With BUILD_WITH_FAILPOINT=yes on Linux and the build tools on PATH, PreInstall returns no archive: PostInstall builds
-- the source. Before that, the release page and the Makefile at the tag are read, to check the release and its target.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

-- os.execute cannot run in a plugin test, so the tools are reported as present.
etcd_utils.has_command = function()
    return true
end

local downloaded = false
local requests = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
    http = function(request)
        table.insert(requests, request.url)
        if string.find(request.url, "/releases/download/", 1, true) then
            downloaded = true
        end
        if request.url == "https://github.com/etcd-io/etcd/releases/tag/v3.4.32" then
            return { status_code = 200, body = "", headers = {} }
        end
        if request.url == "https://raw.githubusercontent.com/etcd-io/etcd/v3.4.32/Makefile" then
            return { status_code = 200, body = "gofail-enable: install-gofail\n\tPASSES=toggle\n", headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local info = plugin:PreInstall({ version = "3.4.32" })
assert(info.version == "3.4.32", tostring(info.version))
assert((info.url or "") == "" and (info.sha256 or "") == "", "a failpoint build has no archive")
assert(not downloaded, "a failpoint build downloads no archive and no SHA256SUMS")
assert(#requests == 2, table.concat(requests, " "))
