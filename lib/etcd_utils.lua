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

local http = require("http")

local etcd_utils = {}

--- Release archives and their SHA256SUMS are published on GitHub, one directory per tag.
etcd_utils.RELEASE_URL = "https://github.com/etcd-io/etcd/releases/download/v"
--- The source of the failpoint build.
etcd_utils.REPOSITORY_URL = "https://github.com/etcd-io/etcd.git"
--- The released versions, one per line. The update_etcd_versions workflow keeps the file current.
etcd_utils.VERSIONS_URL = "https://fastly.jsdelivr.net/gh/version-fox/vfox-etcd@main/assets/versions.txt"
--- A release before this version may be installed without a checksum, when its release publishes none for the
--- archive. From this version on, the checksum is required. Keep it in step with UNVERIFIED_BEFORE in
--- assets/get_all_etcd_versions.py.
etcd_utils.UNVERIFIED_BEFORE = "3.4.0"

-- A release number, with an optional pre-release suffix such as 3.8.0-alpha.0. Only
-- strings of this shape reach a download URL or the shell of the failpoint build.
local VERSION_PATTERN = "^%d+%.%d+%.%d+[%w%.%-]*$"

--- Reports whether version is a release number the plugin can download or build.
--- @param version any
--- @return boolean
function etcd_utils.is_valid_version(version)
    return type(version) == "string" and string.match(version, VERSION_PATTERN) ~= nil
end

--- Removes spaces and line breaks at both ends of value.
--- @param value string
--- @return string
function etcd_utils.trim(value)
    local result = string.gsub(value, "^%s+", "")
    result = string.gsub(result, "%s+$", "")
    return result
end

--- Downloads url and returns the response. Network failures and HTTP errors stop the hook with the URL in the
--- message, except allowed_status, which is returned for the caller to handle.
--- @param url string
--- @param allowed_status integer|nil an HTTP status to return instead of failing, such as 404
--- @return table
local function fetch(url, allowed_status)
    local resp, err = http.get({ url = url })
    if err ~= nil then
        error("could not download " .. url .. ": " .. tostring(err))
    end
    local allowed = allowed_status ~= nil and resp ~= nil and resp.status_code == allowed_status
    if resp == nil or (resp.status_code ~= 200 and not allowed) then
        error("could not download " .. url .. ": HTTP " .. tostring(resp and resp.status_code))
    end
    return resp
end

--- Returns the released versions for `vfox search etcd`.
--- @return table
function etcd_utils.get_release_versions()
    local body = fetch(etcd_utils.VERSIONS_URL).body
    local result = {}
    for line in string.gmatch(body, "[^\n]+") do
        local version = etcd_utils.trim(line)
        if etcd_utils.is_valid_version(version) then
            table.insert(result, { version = version })
        end
    end
    return result
end

--- Returns the name of the release archive etcd publishes for a platform, such as
--- etcd-v3.5.12-linux-amd64.tar.gz or etcd-v3.5.12-windows-amd64.zip.
--- @param version string
--- @param os_type string vfox's RUNTIME.osType: linux, darwin or windows
--- @param arch_type string vfox's RUNTIME.archType: amd64 or arm64
--- @return string
function etcd_utils.archive_name(version, os_type, arch_type)
    local extension = os_type == "linux" and ".tar.gz" or ".zip"
    return "etcd-v" .. version .. "-" .. string.lower(os_type) .. "-" .. string.lower(arch_type) .. extension
end

--- Returns the SHA-256 that etcd's SHA256SUMS lists for file_name, or nil when the release is older than
--- UNVERIFIED_BEFORE and publishes none for it. Any other missing entry is an error: vfox skips the check when
--- no checksum is given, so a silent gap would install an unverified archive.
--- @param version string
--- @param file_name string
--- @return string|nil
function etcd_utils.get_sha256sums(version, file_name)
    local url = etcd_utils.RELEASE_URL .. version .. "/SHA256SUMS"
    local unverified_ok = etcd_utils.allows_unverified(version)
    local resp = fetch(url, unverified_ok and 404 or nil)
    if resp.status_code == 404 then
        return nil
    end
    for line in string.gmatch(resp.body, "[^\n]+") do
        local checksum, name = string.match(line, "^(%x+)%s+%*?(%S+)")
        if name == file_name then
            return checksum
        end
    end
    if unverified_ok then
        return nil
    end
    error("no checksum for " .. file_name .. " in " .. url)
end

--- Reports whether version is older than UNVERIFIED_BEFORE, so that its archive may be installed without a
--- checksum. A pre-release sorts before its release: 3.4.0-rc.1 is older than 3.4.0.
--- @param version string a release number that passed is_valid_version
--- @return boolean
function etcd_utils.allows_unverified(version)
    local function parts(value)
        local major, minor, patch, rest = string.match(value, "^(%d+)%.(%d+)%.(%d+)(.*)$")
        if major == nil then
            return nil
        end
        return { tonumber(major), tonumber(minor), tonumber(patch), rest == "" and 1 or 0 }
    end
    local current = parts(version)
    if current == nil then
        return false
    end
    local limit = parts(etcd_utils.UNVERIFIED_BEFORE)
    for i = 1, 4 do
        if current[i] ~= limit[i] then
            return current[i] < limit[i]
        end
    end
    return false
end

--- Returns the warning that PreInstall prints before it installs an archive without a checksum.
--- @param version string
--- @param file_name string
--- @return string
function etcd_utils.unverified_warning(version, file_name)
    return string.format(
        "WARNING: etcd %s publishes no checksum for %s, so the archive is installed without a check. "
            .. "The plugin allows this for releases before %s; install a release from %s on to have it verified.",
        version,
        file_name,
        etcd_utils.UNVERIFIED_BEFORE,
        etcd_utils.UNVERIFIED_BEFORE
    )
end

--- Reports whether a file can be opened at path. The check is portable, unlike `[ -d ]`, which
--- does not exist in Windows' cmd and breaks on paths with spaces.
--- @param path string
--- @return boolean
function etcd_utils.file_exists(path)
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    file:close()
    return true
end

--- Returns the version printed by `etcd --version`, or nil when the output has none.
--- @param output string
--- @return string|nil
function etcd_utils.parse_version(output)
    local version = string.match(output, "etcd Version:%s*(%S+)")
    if version ~= nil and etcd_utils.is_valid_version(version) then
        return version
    end
    return nil
end

--- Quotes value for a POSIX shell.
--- @param value string
--- @return string
function etcd_utils.shell_quote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

--- Runs the etcd binary with --version and returns the version it reports, or nil when it does not run.
--- @param binary string path of the executable
--- @param os_type string vfox's RUNTIME.osType
--- @return string|nil
function etcd_utils.probe_version(binary, os_type)
    if io.popen == nil then
        return nil
    end
    local quoted = os_type == "windows" and ('"' .. binary .. '"') or etcd_utils.shell_quote(binary)
    local handle = io.popen(quoted .. " --version 2>&1", "r")
    if handle == nil then
        return nil
    end
    local output = handle:read("*a") or ""
    handle:close()
    return etcd_utils.parse_version(output)
end

--- Returns the shell command that builds etcd with failpoints in path. The clone is the release tag of
--- version, so the build matches the version that vfox reports, and not the default branch.
---
--- gofail has to be on PATH before the make targets run, because they look for it there. `go install`
--- puts gofail in GOBIN, or else in the first GOPATH entry, so the command adds that directory to PATH
--- first. The 3.4 line has a `gofail-enable` target, which enables the failpoints itself. Later lines have
--- none, so the command installs gofail and lets the build enable the failpoints: the build needs
--- FAILPOINTS=true for that, or etcd's build script switches them off again.
--- @param path string the vfox install directory
--- @param version string
--- @return string
function etcd_utils.failpoint_build_command(path, version)
    if not etcd_utils.is_valid_version(version) then
        error("invalid etcd version " .. tostring(version))
    end
    return "cd "
        .. etcd_utils.shell_quote(path)
        .. " && git clone --depth 1 --branch v"
        .. version
        .. " "
        .. etcd_utils.REPOSITORY_URL
        .. " etcd"
        .. " && cd etcd"
        .. ' && export PATH="$(go env GOBIN | grep . || echo "$(go env GOPATH | cut -d: -f1)/bin"):$PATH"'
        .. " && if grep -q '^gofail-enable:' Makefile; then make gofail-enable; else make install-gofail; fi"
        .. " && FAILPOINTS=true make build"
end

return etcd_utils
