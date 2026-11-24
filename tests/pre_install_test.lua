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

-- PreInstall on Linux amd64: the archive URL, the checksum taken from SHA256SUMS, and the failures.
local test = require("vfox.test")

local SHA256SUMS_URL = "https://github.com/etcd-io/etcd/releases/download/v3.5.12/SHA256SUMS"
local RELEASE_PAGE = "https://github.com/etcd-io/etcd/releases/tag/v3.5.12"
local ARCHIVE = "etcd-v3.5.12-linux-amd64.tar.gz"
local CHECKSUM = "1111111111111111111111111111111111111111111111111111111111111111"

-- The handler answers from these variables, which a case may change before it calls the hook.
local sums = CHECKSUM
    .. "  "
    .. ARCHIVE
    .. "\n"
    .. "2222222222222222222222222222222222222222222222222222222222222222  etcd-v3.5.12-linux-arm64.tar.gz\n"
local status = 200
local requests = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        table.insert(requests, request.url)
        if request.url == SHA256SUMS_URL then
            return { status_code = status, body = sums, headers = {} }
        end
        if request.url == RELEASE_PAGE then
            return { status_code = 200, body = "", headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local info = plugin:PreInstall({ version = "3.5.12" })
assert(info.version == "3.5.12")
assert(info.url == "https://github.com/etcd-io/etcd/releases/download/v3.5.12/" .. ARCHIVE, info.url)
assert(info.sha256 == CHECKSUM, tostring(info.sha256))

-- A checksum that is missing fails the install: vfox skips verification when none is given.
sums = "2222222222222222222222222222222222222222222222222222222222222222  etcd-v3.5.12-linux-arm64.tar.gz\n"
local ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.12" })
end)
assert(
    not ok and string.find(tostring(err), "etcd 3.5.12 has no Linux amd64 build, see " .. RELEASE_PAGE, 1, true),
    tostring(err)
)
sums = CHECKSUM .. "  " .. ARCHIVE .. "\n"

-- A failed SHA256SUMS download fails too, and names the status.
status = 500
ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.12" })
end)
assert(not ok and string.find(tostring(err), "HTTP 500", 1, true), tostring(err))

-- A release without a SHA256SUMS answers 404, and the install stops with that status.
status = 404
ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.12" })
end)
assert(not ok and string.find(tostring(err), "HTTP 404", 1, true), tostring(err))
status = 200

-- A version that is not a release never reaches the network.
requests = {}
ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.12; id" })
end)
assert(not ok and string.find(tostring(err), "invalid etcd version", 1, true), tostring(err))
assert(#requests == 0, "no request for an invalid version")

-- A release that does not exist stops before its SHA256SUMS is downloaded, and the message names the release.
requests = {}
ok, err = pcall(function()
    return plugin:PreInstall({ version = "9.9.9" })
end)
assert(not ok and string.find(tostring(err), "there is no etcd release 9.9.9", 1, true), tostring(err))
assert(
    #requests == 1 and requests[1] == "https://github.com/etcd-io/etcd/releases/tag/v9.9.9",
    table.concat(requests, " ")
)
