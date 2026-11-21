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

-- BUILD_WITH_FAILPOINT is not supported on Windows: the official build is installed, with a notice.
local test = require("vfox.test")

local ARCHIVE = "etcd-v3.4.32-windows-amd64.zip"
local CHECKSUM = "5555555555555555555555555555555555555555555555555555555555555555"

local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
    http = function(request)
        if request.url == "https://github.com/etcd-io/etcd/releases/download/v3.4.32/SHA256SUMS" then
            return { status_code = 200, body = CHECKSUM .. "  " .. ARCHIVE .. "\n", headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

local info = plugin:PreInstall({ version = "3.4.32" })
assert(info.url == "https://github.com/etcd-io/etcd/releases/download/v3.4.32/" .. ARCHIVE, info.url)
assert(info.sha256 == CHECKSUM, tostring(info.sha256))
