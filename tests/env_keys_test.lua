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

-- EnvKeys on Linux: PATH follows the layout of the install (linked prefix, source build, archive).
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

local present = {}
etcd_utils.file_exists = function(path)
    return present[path] == true
end

local plugin = test.load({ os = "linux", arch = "amd64", env = {} })

local function path_for(root)
    local keys = plugin:EnvKeys({ path = root })
    assert(#keys == 1 and keys[1].key == "PATH", "one PATH entry")
    return keys[1].value
end

-- A system install linked as its prefix keeps its binaries in bin.
present = { ["/usr/bin/etcd"] = true }
assert(path_for("/usr") == "/usr/bin")

-- A source build keeps them in etcd/bin.
present = { ["/home/me/.vfox/sdks/etcd/v-3.4.32/etcd/bin/etcd"] = true }
assert(path_for("/home/me/.vfox/sdks/etcd/v-3.4.32") == "/home/me/.vfox/sdks/etcd/v-3.4.32/etcd/bin")

-- An archive has the binaries at its root.
present = { ["/home/me/.vfox/sdks/etcd/v-3.5.12/etcd"] = true }
assert(path_for("/home/me/.vfox/sdks/etcd/v-3.5.12") == "/home/me/.vfox/sdks/etcd/v-3.5.12")

-- A path with a space is handled the same way: no shell sees it.
present = { ["/home/me/my sdks/etcd-3.5.12/etcd/bin/etcd"] = true }
assert(path_for("/home/me/my sdks/etcd-3.5.12") == "/home/me/my sdks/etcd-3.5.12/etcd/bin")

-- With nothing found, the root is still the PATH entry.
present = {}
assert(path_for("/opt/etcd") == "/opt/etcd")
