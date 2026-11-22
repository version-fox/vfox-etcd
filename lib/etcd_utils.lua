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
local pinned_checksums = require("pinned_checksums")

local etcd_utils = {}

--- Release archives and their SHA256SUMS are published on GitHub, one directory per tag.
etcd_utils.RELEASE_URL = "https://github.com/etcd-io/etcd/releases/download/v"
--- The source of the failpoint build.
etcd_utils.REPOSITORY_URL = "https://github.com/etcd-io/etcd.git"
--- The start of the URL of the released versions, one per line: see versions_url for the rest.
etcd_utils.VERSIONS_URL_PREFIX = "https://fastly.jsdelivr.net/gh/version-fox/vfox-etcd@v"
--- From this version on, every release lists its archives in SHA256SUMS, and an archive it does not list is refused.
--- An older release may publish no SHA256SUMS, so its archives are checked against the SHA-256 values pinned in
--- pinned_checksums.lua. Keep it in step with CHECKSUMS_FROM in assets/get_all_etcd_versions.py.
etcd_utils.CHECKSUMS_FROM = "3.4.0"

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

--- Returns the URL of assets/versions.txt at the release tag of plugin_version. A tag does not move, so every
--- release lists the versions it was released with. The default branch is not read: jsDelivr can serve an old copy
--- of it, and two hosts can disagree. The update_etcd_versions workflow refreshes the file on the default branch, and
--- a release carries that refreshed list once it is tagged.
--- @param plugin_version string the plugin version from metadata.lua, such as 0.2.1
--- @return string
function etcd_utils.versions_url(plugin_version)
    if type(plugin_version) ~= "string" or string.match(plugin_version, "^%d+%.%d+%.%d+$") == nil then
        error("invalid plugin version " .. tostring(plugin_version) .. ", expected a release such as 0.2.1")
    end
    return etcd_utils.VERSIONS_URL_PREFIX .. plugin_version .. "/assets/versions.txt"
end

--- Returns the released versions for `vfox search etcd`, as the release tag of plugin_version lists them.
--- @param plugin_version string
--- @return table
function etcd_utils.get_release_versions(plugin_version)
    local body = fetch(etcd_utils.versions_url(plugin_version)).body
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

--- Reports whether version is older than CHECKSUMS_FROM. A pre-release sorts before its release, so 3.4.0-rc.1 is
--- older than 3.4.0.
--- @param version string a release number that passed is_valid_version
--- @return boolean
function etcd_utils.is_before_checksums(version)
    local function parts(value)
        local major, minor, patch, rest = string.match(value, "^(%d+)%.(%d+)%.(%d+)(.*)$")
        if major == nil then
            return nil
        end
        return { tonumber(major), tonumber(minor), tonumber(patch), rest == "" and 1 or 0 }
    end
    local current = parts(version)
    local limit = parts(etcd_utils.CHECKSUMS_FROM)
    if current == nil or limit == nil then
        return false
    end
    for i = 1, 4 do
        if current[i] ~= limit[i] then
            return current[i] < limit[i]
        end
    end
    return false
end

--- Returns the SHA-256 that pinned_checksums.lua holds for an archive of an old release. Stops with the URL of the
--- SHA256SUMS that did not list the archive when nothing is pinned for it.
--- @param version string
--- @param file_name string
--- @param url string
--- @return string
local function pinned_checksum(version, file_name, url)
    local pins = pinned_checksums[version]
    local checksum = pins and pins[file_name]
    if checksum == nil then
        error("no checksum for " .. file_name .. " in " .. url .. ", and none is pinned for it in this plugin")
    end
    return checksum
end

--- Returns the SHA-256 for file_name of version, and where it comes from: "published" when the release's SHA256SUMS
--- lists the archive, or "pinned" when the release is older than CHECKSUMS_FROM and the plugin pins the archive. Any
--- other missing entry is an error: vfox skips the check when no checksum is given, so a silent gap would install an
--- unverified archive.
--- @param version string
--- @param file_name string
--- @return string checksum
--- @return string source "published" or "pinned"
function etcd_utils.get_sha256sums(version, file_name)
    local url = etcd_utils.RELEASE_URL .. version .. "/SHA256SUMS"
    local before = etcd_utils.is_before_checksums(version)
    local resp = fetch(url, before and 404 or nil)
    if resp.status_code == 404 then
        return pinned_checksum(version, file_name, url), "pinned"
    end
    for line in string.gmatch(resp.body, "[^\n]+") do
        local checksum, name = string.match(line, "^(%x+)%s+%*?(%S+)")
        -- Some releases name each archive by its download URL rather than by its file name.
        if name ~= nil and string.match(name, "([^/]+)$") == file_name then
            return checksum, "published"
        end
    end
    if before then
        return pinned_checksum(version, file_name, url), "pinned"
    end
    error("no checksum for " .. file_name .. " in " .. url)
end

--- Returns the note PreInstall prints when an archive is checked against a pinned SHA-256.
--- @param version string
--- @param file_name string
--- @return string
function etcd_utils.pinned_notice(version, file_name)
    return string.format(
        "etcd %s publishes no checksum for %s, so the archive is checked against the SHA-256 pinned in this plugin.",
        version,
        file_name
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

--- Returns the version printed by `etcd --version`, or nil when the output has none. Release 0.3.0 prints only its
--- tag, such as v0.3.0, and no "etcd Version:" line.
--- @param output string
--- @return string|nil
function etcd_utils.parse_version(output)
    local version = string.match(output, "etcd Version:%s*(%S+)")
    if version == nil then
        version = string.match(output, "^%s*v(%d+%.%d+%.%d+[%w%.%-]*)%s*$")
    end
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
--- first. Some lines have a `gofail-enable` target, which enables the failpoints itself: 3.4 has it in the root
--- Makefile, 3.6 in the makefile that the root Makefile includes. Others, such as 3.5, have none, so the command
--- installs gofail and lets the build enable the failpoints. `make -q` finds the target wherever it is defined: it
--- exits 2 when there is no such target, and 0 or 1 when there is. For 3.4 and 3.5 the build also needs
--- FAILPOINTS=true, or etcd's build script switches the failpoints off again.
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
        .. " && if make -q gofail-enable >/dev/null 2>&1 || [ $? -eq 1 ]; then make gofail-enable; else make install-gofail; fi"
        .. " && FAILPOINTS=true make build"
end

--- The programs a failpoint build runs. They have to be on PATH before the plugin clones etcd.
etcd_utils.BUILD_TOOLS = { "git", "go", "make" }

--- Reports whether name can be run from PATH. `command -v` is a builtin of the POSIX shells that the failpoint
--- build runs in, so the check is for Linux and macOS.
--- @param name string
--- @return boolean
function etcd_utils.has_command(name)
    return os.execute("command -v " .. name .. " >/dev/null 2>&1") == 0
end

--- Returns the BUILD_TOOLS that are not on PATH, in their order.
--- @return table
function etcd_utils.missing_build_tools()
    local missing = {}
    for _, name in ipairs(etcd_utils.BUILD_TOOLS) do
        if not etcd_utils.has_command(name) then
            table.insert(missing, name)
        end
    end
    return missing
end

--- Reports whether the value of BUILD_WITH_FAILPOINT asks for the failpoint build. Only "yes" does. Unset, empty and
--- "no" ask for the official build. Any other value stops the install, so that "1" or "true" cannot install the
--- official build without a word.
--- @param value string|nil the value of BUILD_WITH_FAILPOINT
--- @return boolean
function etcd_utils.failpoint_requested(value)
    if value == nil or value == "" or value == "no" then
        return false
    end
    if value == "yes" then
        return true
    end
    error(
        'BUILD_WITH_FAILPOINT is "'
            .. value
            .. '", but only yes turns on the failpoint build. Unset it to install the official build.'
    )
end

--- The gofail runtime package. The code that a failpoint build instruments imports it, and a build without
--- failpoints does not link it.
local GOFAIL_RUNTIME = "go.etcd.io/gofail/runtime"

--- Reports whether the binary at path links the gofail runtime, which only a build with failpoints does. The file is
--- read rather than run, so the check is the same for every release line, whatever its Git SHA shows.
--- @param path string
--- @return boolean
function etcd_utils.has_failpoints(path)
    local file = io.open(path, "rb")
    if file == nil then
        return false
    end
    local content = file:read("*a") or ""
    file:close()
    return string.find(content, GOFAIL_RUNTIME, 1, true) ~= nil
end

return etcd_utils
