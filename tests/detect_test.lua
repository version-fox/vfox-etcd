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

-- Detect looks at PATH and the usual directories, names each installation <version>-<source>, and skips
-- what vfox manages, version-manager shims, and whatever does not answer to --version.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
test.load({ os = "linux", arch = "amd64", env = {} })
local detect = require("detect_etcd")

-- The file system and the probe are replaced: binaries maps a path to true, versions maps it to the
-- version it reports.
local function fake(binaries, versions)
    local probed = {}
    local options = {
        exists = function(path)
            return binaries[path] ~= nil
        end,
        probe = function(binary)
            table.insert(probed, binary)
            return versions[binary]
        end,
    }
    return options, probed
end

local function names(found)
    local result = {}
    for _, item in ipairs(found) do
        table.insert(result, item.version .. " " .. item.path)
    end
    return table.concat(result, "; ")
end

-- Linux: PATH first, then the fixed directories. A duplicate name or prefix is kept once, and what vfox
-- manages (sdks/etcd and cache/etcd under its home) is never probed.
local env = {
    HOME = "/home/me",
    PATH = "/usr/local/bin:/usr/bin:/home/me/tools/bin:/home/me/.vfox/sdks/etcd-tools/bin:/usr/bin/"
        .. ":/home/me/.vfox/cache/etcd/v-3.5.12/etcd-3.5.12/bin:/home/me/.vfox/sdks/etcd/v-3.5.12/bin"
        .. ":/home/me/.local/share/mise/shims",
}
local options, probed = fake({
    ["/usr/local/bin/etcd"] = true,
    ["/usr/bin/etcd"] = true,
    ["/home/me/tools/bin/etcd"] = true,
    ["/home/me/.vfox/sdks/etcd-tools/bin/etcd"] = true,
    ["/home/me/.vfox/cache/etcd/v-3.5.12/etcd-3.5.12/bin/etcd"] = true,
    ["/home/me/.vfox/sdks/etcd/v-3.5.12/bin/etcd"] = true,
    ["/home/me/.local/share/mise/shims/etcd"] = true,
    ["/opt/homebrew/bin/etcd"] = true,
}, {
    ["/usr/local/bin/etcd"] = "3.4.32",
    ["/usr/bin/etcd"] = "3.5.12",
    ["/home/me/tools/bin/etcd"] = "3.5.12",
    ["/home/me/.vfox/sdks/etcd-tools/bin/etcd"] = "3.6.0",
    ["/opt/homebrew/bin/etcd"] = "3.8.0-alpha.0",
})
options.os = "linux"
options.getenv = function(name)
    return env[name]
end
local found = detect.find_all(options)
assert(
    names(found)
        == "3.4.32-local /usr/local; 3.5.12-system /usr; 3.5.12-path /home/me/tools; "
            .. "3.6.0-path /home/me/.vfox/sdks/etcd-tools; 3.8.0-alpha.0-brew /opt/homebrew",
    names(found)
)
assert(found[2].note == "/usr/bin/etcd", found[2].note)
for _, binary in ipairs(probed) do
    assert(binary ~= "/home/me/.local/share/mise/shims/etcd", "shims are not probed")
    assert(binary ~= "/home/me/.vfox/sdks/etcd/v-3.5.12/bin/etcd", "vfox installs are not probed")
    assert(binary ~= "/home/me/.vfox/cache/etcd/v-3.5.12/etcd-3.5.12/bin/etcd", "vfox caches are not probed")
end

-- A binary that does not report an etcd version is left out.
options = fake({ ["/usr/bin/etcd"] = true }, {})
options.os = "linux"
options.getenv = function(name)
    return name == "PATH" and "/usr/bin" or nil
end
assert(#detect.find_all(options) == 0, "no version, no installation")

-- Windows: PATH with semicolons and quoted entries, Program Files and Scoop.
local windows_env = {
    USERPROFILE = "C:\\Users\\me",
    ProgramFiles = "C:\\Program Files",
    ["ProgramFiles(x86)"] = "C:\\Program Files (x86)",
    VFOX_HOME = "C:\\Users\\me\\.vfox",
    PATH = '"C:\\tools\\etcd\\bin";C:\\Program Files\\etcd;C:\\Users\\me\\scoop\\apps\\etcd\\current',
}
options = fake({
    ["C:\\tools\\etcd\\bin\\etcd.exe"] = true,
    ["C:\\Program Files\\etcd\\etcd.exe"] = true,
    ["C:\\Users\\me\\scoop\\apps\\etcd\\current\\etcd.exe"] = true,
}, {
    ["C:\\tools\\etcd\\bin\\etcd.exe"] = "3.5.12",
    ["C:\\Program Files\\etcd\\etcd.exe"] = "3.4.32",
    ["C:\\Users\\me\\scoop\\apps\\etcd\\current\\etcd.exe"] = "3.5.12",
})
options.os = "windows"
options.getenv = function(name)
    return windows_env[name]
end
found = detect.find_all(options)
assert(
    names(found)
        == "3.5.12-path C:\\tools\\etcd; 3.4.32-system C:\\Program Files\\etcd; "
            .. "3.5.12-scoop C:\\Users\\me\\scoop\\apps\\etcd\\current",
    names(found)
)

-- A vfox install on Windows is skipped, whatever the case of the PATH entry that points at it.
local vfox_dir = "c:\\users\\ME\\.VFOX\\sdks\\etcd\\v-3.5.12"
options = fake({ [vfox_dir .. "\\etcd.exe"] = true }, { [vfox_dir .. "\\etcd.exe"] = "3.5.12" })
options.os = "windows"
options.getenv = function(name)
    if name == "PATH" then
        return vfox_dir
    end
    return windows_env[name]
end
assert(#detect.find_all(options) == 0, "vfox installs are skipped")
