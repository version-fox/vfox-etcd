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

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table Context information; ctx.version is the version the user asked for
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local etcd_version = ctx.version
    if not etcdUtils.is_valid_version(etcd_version) then
        error("invalid etcd version " .. tostring(etcd_version) .. ", expected a release such as 3.5.12")
    end

    -- Build etcd with failpoints from source: https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally
    if os.getenv("BUILD_WITH_FAILPOINT") == "yes" then
        if RUNTIME.osType ~= "windows" then
            -- PostInstall builds the source, so there is nothing to download.
            return {
                version = etcd_version,
            }
        end
        print("BUILD_WITH_FAILPOINT is only supported on Linux and macOS, installing the official Windows build.")
    end

    local file = etcdUtils.archive_name(etcd_version, RUNTIME.osType, RUNTIME.archType)
    local checksum, source = etcdUtils.get_sha256sums(etcd_version, file)
    local download_url = etcdUtils.RELEASE_URL .. etcd_version .. "/" .. file
    print("etcd download url: " .. download_url)
    if source == "pinned" then
        print(etcdUtils.pinned_notice(etcd_version, file))
    end

    return {
        version = etcd_version,
        url = download_url,
        sha256 = checksum,
    }
end
