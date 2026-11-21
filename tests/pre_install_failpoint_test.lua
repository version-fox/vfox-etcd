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

-- With BUILD_WITH_FAILPOINT=yes on Linux, PreInstall returns no download: PostInstall builds the source.
local test = require("vfox.test")

local requested = false
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
    http = function(request)
        requested = true
        return { status_code = 404, body = "", headers = {} }
    end,
})

local info = plugin:PreInstall({ version = "3.4.32" })
assert(info.version == "3.4.32", tostring(info.version))
assert((info.url or "") == "" and (info.sha256 or "") == "", "a failpoint build has no archive")
assert(not requested, "a failpoint build does not download SHA256SUMS")
