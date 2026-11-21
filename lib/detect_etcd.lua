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

local etcd_utils = require("etcd_utils")

local detect = {}

-- Where package managers put etcd on Unix-like systems. PATH is searched first, so an
-- installation the user runs wins over one that only sits in these directories.
local UNIX_DIRS = {
    "/usr/bin",
    "/usr/local/bin",
    "/opt/homebrew/bin",
    "/home/linuxbrew/.linuxbrew/bin",
}

--- Returns the directories to probe, most relevant first. Duplicates are removed by the caller.
--- @param os_type string
--- @param getenv function
--- @return table
function detect.candidate_dirs(os_type, getenv)
    local windows = os_type == "windows"
    local separator = windows and ";" or ":"
    local dirs = {}
    for entry in string.gmatch(getenv("PATH") or "", "[^" .. separator .. "]+") do
        local dir = etcd_utils.trim((string.gsub(entry, '"', "")))
        if dir ~= "" then
            table.insert(dirs, dir)
        end
    end
    if windows then
        for _, name in ipairs({ "ProgramFiles", "ProgramFiles(x86)" }) do
            local root = getenv(name)
            if root ~= nil and root ~= "" then
                table.insert(dirs, root .. "\\etcd")
            end
        end
        local home = getenv("USERPROFILE")
        if home ~= nil and home ~= "" then
            table.insert(dirs, home .. "\\scoop\\apps\\etcd\\current")
        end
    else
        for _, dir in ipairs(UNIX_DIRS) do
            table.insert(dirs, dir)
        end
    end
    return dirs
end

-- Compares paths the way the platform does: Windows ignores case and accepts both slashes.
local function normalize(path, windows)
    local result = string.gsub(path, "\\", "/")
    if windows then
        result = string.lower(result)
    end
    return result
end

-- Drops trailing slashes, but keeps a bare root such as "/".
local function strip_trailing(dir)
    local stripped = string.gsub(dir, "[/\\]+$", "")
    if stripped == "" then
        return dir
    end
    return stripped
end

-- The directory that vfox links: bin's parent for /usr/bin, so PATH gets /usr/bin back, and the
-- directory itself for an archive, whose binaries sit at its root.
local function prefix_of(dir)
    local parent = string.match(dir, "^(.*)[/\\]bin$")
    if parent == nil or parent == "" then
        return dir
    end
    return parent
end

-- The installations that vfox manages, under sdks/etcd and cache/etcd, and the shims of version
-- managers, which only forward to an installation that is elsewhere.
local function is_managed(dir, os_type, getenv)
    local windows = os_type == "windows"
    local separator = windows and "\\" or "/"
    local vfox_home = getenv("VFOX_HOME")
    if vfox_home == nil or vfox_home == "" then
        local home = getenv(windows and "USERPROFILE" or "HOME")
        if home == nil or home == "" then
            return false
        end
        vfox_home = home .. separator .. ".vfox"
    end
    local normalized = normalize(dir, windows)
    for _, sub in ipairs({ "sdks", "cache" }) do
        local root = normalize(vfox_home .. separator .. sub .. separator .. "etcd", windows)
        -- Whole path segments only: .../sdks/etcd-tools is not an installation of vfox.
        if normalized == root or string.sub(normalized, 1, #root + 1) == root .. "/" then
            return true
        end
    end
    return string.match(normalized, "([^/]+)$") == "shims"
end

local function is_homebrew(dir)
    for _, marker in ipairs({ "/homebrew/", "linuxbrew", "/Cellar/" }) do
        if string.find(dir, marker, 1, true) then
            return true
        end
    end
    return false
end

-- The source named after the version, so `vfox use` can tell the installations apart.
local function source_of(dir, os_type, getenv)
    if os_type == "windows" then
        local normalized = normalize(dir, true)
        if string.find(normalized, "/scoop/", 1, true) then
            return "scoop"
        end
        for _, name in ipairs({ "ProgramFiles", "ProgramFiles(x86)" }) do
            local root = getenv(name)
            if root ~= nil and root ~= "" and string.sub(normalized, 1, #root) == normalize(root, true) then
                return "system"
            end
        end
        return "path"
    end
    if is_homebrew(dir) then
        return "brew"
    end
    if string.sub(dir, 1, 10) == "/usr/local" then
        return "local"
    end
    if string.sub(dir, 1, 4) == "/usr" or dir == "/bin" or dir == "/sbin" then
        return "system"
    end
    if string.sub(dir, 1, 5) == "/opt/" then
        return "opt"
    end
    return "path"
end

--- Finds etcd installations that are on this machine and that vfox did not install. Each result is
--- named <version>-<source>, such as 3.5.12-system or 3.5.12-brew, and the first one of a name wins.
--- @param options table|nil os, getenv, exists and probe replace the host's values; the tests use them
--- @return table list of { version = name, path = prefix, note = binary }
function detect.find_all(options)
    options = options or {}
    local os_type = options.os or RUNTIME.osType
    local getenv = options.getenv or os.getenv
    local exists = options.exists or etcd_utils.file_exists
    local probe = options.probe or function(binary)
        return etcd_utils.probe_version(binary, os_type)
    end
    local windows = os_type == "windows"
    local binary_name = windows and "etcd.exe" or "etcd"
    local separator = windows and "\\" or "/"

    local found = {}
    local seen_dirs, seen_names, seen_prefixes = {}, {}, {}
    for _, candidate in ipairs(detect.candidate_dirs(os_type, getenv)) do
        local dir = strip_trailing(candidate)
        local key = normalize(dir, windows)
        if not seen_dirs[key] and not is_managed(dir, os_type, getenv) then
            seen_dirs[key] = true
            local binary = dir .. separator .. binary_name
            if exists(binary) then
                local version = probe(binary)
                if version ~= nil then
                    local name = version .. "-" .. source_of(dir, os_type, getenv)
                    local prefix = prefix_of(dir)
                    local prefix_key = normalize(prefix, windows)
                    if not seen_names[name] and not seen_prefixes[prefix_key] then
                        seen_names[name] = true
                        seen_prefixes[prefix_key] = true
                        table.insert(found, { version = name, path = prefix, note = binary })
                    end
                end
            end
        end
    end
    return found
end

return detect
