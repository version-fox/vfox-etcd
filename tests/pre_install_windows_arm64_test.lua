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

-- PreInstall on Windows arm64. etcd publishes no arm64 archive for Windows, so a release whose SHA256SUMS lists
-- only the amd64 archive is refused before the archive is requested. An arm64 archive that the release lists is
-- installed like any other.
local test = require("vfox.test")

local VERSION = "3.7.4"
local RELEASE_PAGE = "https://github.com/etcd-io/etcd/releases/tag/v3.7.4"
local SHA256SUMS_URL = "https://github.com/etcd-io/etcd/releases/download/v3.7.4/SHA256SUMS"
local ARCHIVE = "etcd-v3.7.4-windows-arm64.zip"
local ARCHIVE_URL = "https://github.com/etcd-io/etcd/releases/download/v3.7.4/" .. ARCHIVE
local CHECKSUM = "3333333333333333333333333333333333333333333333333333333333333333"

-- The handler answers from these variables, which a case may change before it calls the hook. Upstream lists the
-- Windows amd64 archive only, and that is the list the first case refuses.
local sums = "4444444444444444444444444444444444444444444444444444444444444444  etcd-v3.7.4-windows-amd64.zip\n"
local requests = {}

local plugin = test.load({
    os = "windows",
    arch = "arm64",
    env = {},
    http = function(request)
        table.insert(requests, request.url)
        if request.url == RELEASE_PAGE then
            return { status_code = 200, body = "", headers = {} }
        end
        if request.url == SHA256SUMS_URL then
            return { status_code = 200, body = sums, headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- No arm64 build: the install stops with a message that names the platform, and the archive is never requested.
local ok, err = pcall(function()
    return plugin:PreInstall({ version = VERSION })
end)
assert(
    not ok and string.find(tostring(err), "etcd 3.7.4 has no Windows arm64 build, see " .. RELEASE_PAGE, 1, true),
    tostring(err)
)
assert(#requests == 2 and requests[1] == RELEASE_PAGE and requests[2] == SHA256SUMS_URL, table.concat(requests, " "))

-- The release lists the arm64 archive: the install goes on with its URL and its checksum.
sums = CHECKSUM .. "  " .. ARCHIVE .. "\n" .. sums
requests = {}
local info = plugin:PreInstall({ version = VERSION })
assert(info.version == VERSION, tostring(info.version))
assert(info.url == ARCHIVE_URL, info.url)
assert(info.sha256 == CHECKSUM, tostring(info.sha256))
assert(#requests == 2, table.concat(requests, " "))
