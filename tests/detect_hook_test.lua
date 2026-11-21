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

-- The Detect hook is wired to the scan. The machine running the tests may have an etcd of its own, so
-- the results are only checked for shape here; detect_test.lua checks the rules with fixed inputs.
local test = require("vfox.test")

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { PATH = "", HOME = "/nonexistent/vfox-etcd-test" },
})
local found = plugin:Detect({})
assert(type(found) == "table", "Detect returns a list")
for _, item in ipairs(found) do
    assert(string.match(item.version, "^%d+%.%d+%.%d+[%w%.%-]*%-%a+$"), "name: " .. tostring(item.version))
    assert(type(item.path) == "string" and item.path ~= "", "path of " .. item.version)
end
