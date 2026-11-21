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

local etcdUtils = require("etcd_utils")

--- Each SDK may have different environment variable configurations.
--- This allows plugins to define custom environment variables (including PATH settings)
--- Note: Be sure to distinguish between environment variable settings for different platforms!
--- @param ctx table Context information; ctx.path is the SDK installation directory
function PLUGIN:EnvKeys(ctx)
    local separator = RUNTIME.osType == "windows" and "\\" or "/"
    local binary = RUNTIME.osType == "windows" and "etcd.exe" or "etcd"
    -- The binaries sit in <path>/bin for a linked system install, in <path>/etcd/bin for a source
    -- build, and at the root of <path> for an archive. The first layout that has etcd wins.
    local layouts = {
        ctx.path .. separator .. "bin",
        ctx.path .. separator .. "etcd" .. separator .. "bin",
    }
    for _, dir in ipairs(layouts) do
        if etcdUtils.file_exists(dir .. separator .. binary) then
            return {
                { key = "PATH", value = dir },
            }
        end
    end
    return {
        { key = "PATH", value = ctx.path },
    }
end
