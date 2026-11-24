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

-- PreInstall on Windows arm64 for a release before 3.4.0. Its SHA256SUMS does not list a Windows arm64 archive, and the
-- plugin pins none, so the install is refused before the archive is requested. The message says that the plugin has no
-- checksum for the platform: a release from this era may publish no SHA256SUMS, and the plugin knows only what it pins.
local test = require("vfox.test")

local VERSION = "3.3.13"
local RELEASE_PAGE = "https://github.com/etcd-io/etcd/releases/tag/v3.3.13"
local SHA256SUMS_URL = "https://github.com/etcd-io/etcd/releases/download/v3.3.13/SHA256SUMS"
local ARCHIVE = "etcd-v3.3.13-windows-arm64.zip"
local ARCHIVE_URL = "https://github.com/etcd-io/etcd/releases/download/v3.3.13/" .. ARCHIVE
local CHECKSUM = "3333333333333333333333333333333333333333333333333333333333333333"
local MESSAGE = "etcd 3.3.13 has no Windows arm64 build that the plugin has a checksum for, see "
    .. RELEASE_PAGE
    .. " for the archives it has"

-- The lines the hook prints. A refusal prints its message and returns nothing, instead of raising an error.
local printed = {}
print = function(line)
    table.insert(printed, line)
end

-- The handler answers from these variables, which a case may change before it calls the hook. The release lists its
-- Windows amd64 archive and no arm64 one. status is the answer for SHA256SUMS: 404 for a release that has none.
local sums = "4444444444444444444444444444444444444444444444444444444444444444  etcd-v3.3.13-windows-amd64.zip\n"
local status = 200
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
            return { status_code = status, body = sums, headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- Runs PreInstall, and returns what it returned, the lines it printed and the URLs it requested.
local function install()
    printed = {}
    requests = {}
    local info = plugin:PreInstall({ version = VERSION })
    return info, table.concat(printed, "\n"), table.concat(requests, " ")
end

-- A SHA256SUMS that lists no Windows arm64 archive refuses the install, and the archive is never requested.
local info, message, requested = install()
assert(info == nil, tostring(info))
assert(message == MESSAGE, message)
assert(requested == RELEASE_PAGE .. " " .. SHA256SUMS_URL, requested)

-- A release that publishes no SHA256SUMS refuses the install the same way.
status = 404
info, message = install()
assert(info == nil, tostring(info))
assert(message == MESSAGE, message)
status = 200

-- A SHA256SUMS that lists the Windows arm64 archive installs it, as it does for any release.
sums = CHECKSUM .. "  " .. ARCHIVE .. "\n" .. sums
info = install()
assert(info.version == VERSION, tostring(info.version))
assert(info.url == ARCHIVE_URL, info.url)
assert(info.sha256 == CHECKSUM, tostring(info.sha256))
