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

-- Available lists the versions in versions.txt, and fails loudly when the list cannot be downloaded.
local test = require("vfox.test")

local VERSIONS_URL = "https://fastly.jsdelivr.net/gh/version-fox/vfox-etcd@main/assets/versions.txt"
local body = "3.8.0-alpha.0\n3.5.12\r\n\n3.4.32\nnot a version\n"
local status = 200

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        assert(request.url == VERSIONS_URL, request.url)
        return { status_code = status, body = body, headers = {} }
    end,
})

local versions = plugin:Available({})
local got = {}
for _, item in ipairs(versions) do
    table.insert(got, item.version)
end
assert(table.concat(got, ",") == "3.8.0-alpha.0,3.5.12,3.4.32", table.concat(got, ","))

status = 503
local ok, err = pcall(function()
    return plugin:Available({})
end)
assert(not ok and string.find(tostring(err), "HTTP 503", 1, true), tostring(err))
