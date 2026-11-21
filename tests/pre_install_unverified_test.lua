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

-- PreInstall on Linux amd64 for releases before 3.4.0: an archive without a checksum is installed with a warning,
-- a checksum that is listed is always used, and a failure other than 404 still stops the install.
local test = require("vfox.test")

local BASE = "https://github.com/etcd-io/etcd/releases/download/v"
local CHECKSUM = "3333333333333333333333333333333333333333333333333333333333333333"
local answers = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        return answers[request.url] or { status_code = 404, body = "", headers = {} }
    end,
})

local printed = {}
print = function(line)
    table.insert(printed, line)
end

local function install(version)
    printed = {}
    local info = plugin:PreInstall({ version = version })
    return info, table.concat(printed, "\n")
end

local function failure(version)
    local ok, err = pcall(function()
        return plugin:PreInstall({ version = version })
    end)
    assert(not ok, "should stop: " .. version)
    return tostring(err)
end

-- 3.3.13 publishes no SHA256SUMS: the archive is installed without a checksum, and the plugin says why.
local info, output = install("3.3.13")
assert(info.url == BASE .. "3.3.13/etcd-v3.3.13-linux-amd64.tar.gz", info.url)
assert(info.sha256 == nil, "no checksum is given to vfox")
assert(
    string.find(output, "WARNING: etcd 3.3.13 publishes no checksum for etcd-v3.3.13-linux-amd64.tar.gz", 1, true),
    output
)

-- 3.4.0-rc.1 is a pre-release of 3.4.0, so it is older than 3.4.0 and may go without a checksum too.
info = install("3.4.0-rc.1")
assert(info.sha256 == nil)

-- A checksum that is listed is used, as for any release, and no warning is printed.
answers[BASE .. "3.3.19/SHA256SUMS"] = {
    status_code = 200,
    body = CHECKSUM .. "  etcd-v3.3.19-linux-amd64.tar.gz\n",
    headers = {},
}
info, output = install("3.3.19")
assert(info.sha256 == CHECKSUM, tostring(info.sha256))
assert(not string.find(output, "WARNING", 1, true), output)

-- A checksum file without an entry for the archive is treated like a missing one, for a release before 3.4.0.
answers[BASE .. "3.3.19/SHA256SUMS"] = {
    status_code = 200,
    body = CHECKSUM .. "  etcd-v3.3.19-darwin-amd64.zip\n",
    headers = {},
}
info, output = install("3.3.19")
assert(info.sha256 == nil, tostring(info.sha256))
assert(string.find(output, "WARNING: etcd 3.3.19", 1, true), output)

-- A failure other than 404 stops the install, even for an old release.
answers[BASE .. "3.3.13/SHA256SUMS"] = { status_code = 500, body = "", headers = {} }
assert(string.find(failure("3.3.13"), "HTTP 500", 1, true))
answers[BASE .. "3.3.13/SHA256SUMS"] = nil

-- From 3.4.0 on, a release without a checksum stops the install, and so does a pre-release of a later line.
assert(string.find(failure("3.4.0"), "HTTP 404", 1, true))
assert(string.find(failure("3.5.0-alpha.0"), "HTTP 404", 1, true))
