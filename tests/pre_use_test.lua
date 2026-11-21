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

-- PreUse selects an installed version, and says how to install one that is missing.
local test = require("vfox.test")

local plugin = test.load({ os = "linux", arch = "amd64", env = {} })

local selected = plugin:PreUse({
    version = "3.5.12",
    installedSdks = {
        ["3.5.12"] = { path = "/home/me/.vfox/sdks/etcd/v-3.5.12", version = "3.5.12", name = "etcd" },
    },
})
assert(selected.version == "3.5.12", tostring(selected.version))

local ok, err = pcall(function()
    return plugin:PreUse({ version = "3.4.32", installedSdks = {} })
end)
assert(not ok and string.find(tostring(err), "vfox install etcd@3.4.32", 1, true), tostring(err))
