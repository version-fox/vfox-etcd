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

-- BUILD_WITH_FAILPOINT turns the failpoint build on only with yes. Another value stops the install, so that it does
-- not install the official build without a word.
local test = require("vfox.test")

local requested = false
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "1" },
    http = function(request)
        requested = true
        return { status_code = 404, body = "", headers = {} }
    end,
})

local ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.5.12" })
end)
assert(not ok and string.find(tostring(err), 'BUILD_WITH_FAILPOINT is "1"', 1, true), tostring(err))
assert(not requested, "an unrecognised value downloads nothing")
