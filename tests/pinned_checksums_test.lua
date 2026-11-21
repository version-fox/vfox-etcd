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

-- The pinned SHA-256 values are well formed, and each one belongs to a release before 3.4.0 and to a supported platform.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
test.load({ os = "linux", arch = "amd64", env = {} })
local etcd_utils = require("etcd_utils")
local pinned = require("pinned_checksums")

local PLATFORM_SUFFIXES = {
    "linux-amd64.tar.gz",
    "linux-arm64.tar.gz",
    "linux-ppc64le.tar.gz",
    "linux-s390x.tar.gz",
    "darwin-amd64.zip",
    "darwin-arm64.zip",
    "windows-amd64.zip",
}

local count = 0
for version, archives in pairs(pinned) do
    assert(etcd_utils.is_valid_version(version), "not a release: " .. version)
    assert(etcd_utils.is_before_checksums(version), "a pinned release must be before 3.4.0: " .. version)
    for name, checksum in pairs(archives) do
        local prefix = "etcd-v" .. version .. "-"
        assert(string.sub(name, 1, #prefix) == prefix, "archive of another release: " .. name)
        local supported = false
        for _, suffix in ipairs(PLATFORM_SUFFIXES) do
            if string.sub(name, -#suffix) == suffix then
                supported = true
            end
        end
        assert(supported, "unsupported platform: " .. name)
        assert(
            #checksum == 64 and string.match(checksum, "^[0-9a-f]+$") ~= nil,
            name .. " has no SHA-256: " .. checksum
        )
        count = count + 1
    end
end
assert(count > 0, "some archives are pinned")
