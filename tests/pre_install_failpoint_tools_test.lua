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

-- With BUILD_WITH_FAILPOINT=yes, PreInstall stops before anything is cloned when git, go or make is not on PATH, and
-- names the missing ones.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

-- go is missing here, as on a machine with git and make only.
local present = { git = true, make = true }
etcd_utils.has_command = function(name)
    return present[name] == true
end

-- The lines the hook prints. A refusal prints its message and returns nothing, instead of raising an error.
local printed = {}
print = function(line)
    table.insert(printed, line)
end

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

local refused = plugin:PreInstall({ version = "3.5.12" })
assert(refused == nil, tostring(refused))
assert(#printed == 1 and string.find(printed[1], "git, go, make on PATH", 1, true), table.concat(printed, "\n"))
assert(string.find(printed[1], "not found: go", 1, true), printed[1])
assert(not requested, "nothing is downloaded when a build tool is missing")
