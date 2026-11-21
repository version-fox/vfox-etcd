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

package.path = "./lib/?.lua;" .. package.path

-- EnvKeys on Windows looks for etcd.exe, not etcd.
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

local present = {}
etcd_utils.file_exists = function(path)
    return present[path] == true
end

local plugin = test.load({ os = "windows", arch = "amd64", env = {} })

present = { ["C:\\tools\\etcd\\bin\\etcd.exe"] = true }
local keys = plugin:EnvKeys({ path = "C:\\tools\\etcd" })
assert(keys[1].key == "PATH" and keys[1].value == "C:\\tools\\etcd\\bin", tostring(keys[1].value))

present = { ["C:\\tools\\etcd\\etcd.exe"] = true }
keys = plugin:EnvKeys({ path = "C:\\tools\\etcd" })
assert(keys[1].value == "C:\\tools\\etcd", tostring(keys[1].value))

-- The Unix name does not count on Windows.
present = { ["C:\\tools\\etcd\\bin\\etcd"] = true }
keys = plugin:EnvKeys({ path = "C:\\tools\\etcd" })
assert(keys[1].value == "C:\\tools\\etcd", tostring(keys[1].value))
