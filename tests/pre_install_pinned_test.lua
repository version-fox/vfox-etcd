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

-- PreInstall for an archive of a release before 3.4.0 uses the checksum the release publishes, and the SHA-256 pinned
-- in pinned_checksums.lua when it publishes none. A release with no pin, a failure other than 404, and a release from
-- 3.4.0 on without a checksum all stop the install.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local pinned = require("pinned_checksums")

local BASE = "https://github.com/etcd-io/etcd/releases/download/v"
local PUBLISHED = "3333333333333333333333333333333333333333333333333333333333333333"
local answers = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        -- Every release used here exists, so its release page answers 200.
        if string.find(request.url, "/releases/tag/v", 1, true) then
            return { status_code = 200, body = "", headers = {} }
        end
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

local function publish(version, body)
    answers[BASE .. version .. "/SHA256SUMS"] = { status_code = 200, body = body, headers = {} }
end

-- 3.3.13 lists its archives by download URL, and the entry for linux-amd64 is the published checksum.
publish("3.3.13", PUBLISHED .. " " .. BASE .. "3.3.13/etcd-v3.3.13-linux-amd64.tar.gz\n")
local info, output = install("3.3.13")
assert(info.sha256 == PUBLISHED, tostring(info.sha256))
assert(info.url == BASE .. "3.3.13/etcd-v3.3.13-linux-amd64.tar.gz", info.url)
assert(not string.find(output, "pinned", 1, true), output)
answers[BASE .. "3.3.13/SHA256SUMS"] = nil

-- 0.4.9 publishes no SHA256SUMS, so its linux-amd64 archive is checked against the pinned value.
local PINNED = pinned["0.4.9"]["etcd-v0.4.9-linux-amd64.tar.gz"]
info, output = install("0.4.9")
assert(info.sha256 == PINNED, tostring(info.sha256))
assert(string.find(output, "SHA-256 pinned in this plugin", 1, true), output)

-- A SHA256SUMS that leaves out the archive falls back to the pinned value as well.
publish("0.4.9", PUBLISHED .. "  etcd-v0.4.9-darwin-amd64.zip\n")
info = install("0.4.9")
assert(info.sha256 == PINNED, tostring(info.sha256))
answers[BASE .. "0.4.9/SHA256SUMS"] = nil

-- A release with no pinned archive, such as 0.1.0, which has no linux-amd64 archive, stops the install.
assert(string.find(failure("0.1.0"), "none is pinned", 1, true))

-- A failure other than 404 stops the install, even for an old release.
answers[BASE .. "3.3.13/SHA256SUMS"] = { status_code = 500, body = "", headers = {} }
assert(string.find(failure("3.3.13"), "HTTP 500", 1, true))
answers[BASE .. "3.3.13/SHA256SUMS"] = nil

-- From 3.4.0 on, a release without a checksum stops the install, and so does a pre-release of a later line.
assert(string.find(failure("3.4.0"), "HTTP 404", 1, true))
assert(string.find(failure("3.5.0-alpha.0"), "HTTP 404", 1, true))
