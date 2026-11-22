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

--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
--- @param ctx table Context information; ctx.sdkInfo['etcd'] holds the installed path and version
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["etcd"]
    local path = sdkInfo.path
    print("etcd installed path: " .. path)

    if etcdUtils.failpoint_requested(os.getenv("BUILD_WITH_FAILPOINT")) and RUNTIME.osType ~= "windows" then
        -- Builds the release tag of the installed version, with failpoints enabled.
        local status = os.execute(etcdUtils.failpoint_build_command(path, sdkInfo.version))
        if status ~= 0 then
            error("etcd build with failpoint failed, check the output above for details.")
        end
        -- A build can finish without failpoints, as 3.6.0 did before its gofail-enable target was found. Such a
        -- binary is an error, so the install does not look complete.
        local binary = path .. "/etcd/bin/etcd"
        if not etcdUtils.has_failpoints(binary) then
            error(
                "etcd "
                    .. sdkInfo.version
                    .. " was built without failpoints: "
                    .. binary
                    .. " does not link the gofail runtime. Uninstall the version and install it again."
            )
        end
    end
end
