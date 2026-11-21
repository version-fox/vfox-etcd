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

-- Without BUILD_WITH_FAILPOINT, PostInstall runs no build.
local test = require("vfox.test")

local executed = 0
os.execute = function(command)
    executed = executed + 1
    return 0
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
})
plugin:PostInstall({
    sdkInfo = {
        etcd = { path = "/home/me/.vfox/sdks/etcd/v-3.5.12", version = "3.5.12", name = "etcd" },
    },
})
assert(executed == 0, "no build without BUILD_WITH_FAILPOINT")
