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

-- A release whose Makefile has no gofail target has no failpoint build. PreInstall reads the Makefile at the
-- release tag before anything is cloned, and refuses such a release. 3.5.5 has no target, and 3.5.12 has one.
package.path = "./lib/?.lua;" .. package.path
local test = require("vfox.test")
local etcd_utils = require("etcd_utils")

-- The build tools are reported as present, so only the release can stop the install.
etcd_utils.has_command = function()
    return true
end

local RAW = "https://raw.githubusercontent.com/etcd-io/etcd/v"
local MAKEFILES = {
    -- 3.5.5 has no gofail target and includes no file.
    [RAW .. "3.5.5/Makefile"] = "build:\n\tgo build\n",
    [RAW .. "3.5.12/Makefile"] = "build:\n\tgo build\n\ninstall-gofail:\n\tgo install go.etcd.io/gofail\n",
    -- 3.6.0-rc.0 defines its gofail-enable target in the file that its Makefile includes.
    [RAW .. "3.6.0-rc.0/Makefile"] = "include tests/robustness/makefile.mk\n",
    [RAW .. "3.6.0-rc.0/tests/robustness/makefile.mk"] = "gofail-enable: install-gofail\n\tPASSES=toggle\n",
    [RAW .. "3.6.0-alpha.0/Makefile"] = "build:\n\tgo build\n",
    -- 3.7 includes its file through the repository root, which the path drops.
    [RAW .. "3.7.4/Makefile"] = "REPOSITORY_ROOT := x\ninclude $(REPOSITORY_ROOT)/tests/robustness/Makefile\n",
    [RAW .. "3.7.4/tests/robustness/Makefile"] = "install-gofail: $(GOPATH)/bin/gofail\n\tgo install\n",
}

-- The lines the hook prints. A refusal prints its message and returns nothing, instead of raising an error.
local printed = {}
print = function(line)
    table.insert(printed, line)
end

local requests = {}
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { BUILD_WITH_FAILPOINT = "yes" },
    http = function(request)
        table.insert(requests, request.url)
        if string.find(request.url, "/releases/tag/v", 1, true) then
            -- 9.9.9 has no release. Every other release used here exists.
            if string.find(request.url, "/v9.9.9", 1, true) then
                return { status_code = 404, body = "", headers = {} }
            end
            return { status_code = 200, body = "", headers = {} }
        end
        if MAKEFILES[request.url] then
            return { status_code = 200, body = MAKEFILES[request.url], headers = {} }
        end
        return { status_code = 404, body = "", headers = {} }
    end,
})

-- Runs PreInstall for version, and returns what it returned, with the requests it made and the lines it printed.
local function install(version)
    requests = {}
    printed = {}
    return plugin:PreInstall({ version = version })
end

local info = install("3.5.5")
assert(info == nil, tostring(info))
assert(
    #printed == 1 and string.find(printed[1], "etcd 3.5.5 has no failpoint build", 1, true),
    table.concat(printed, "\n")
)
assert(string.find(printed[1], "such as 3.5.12", 1, true), printed[1])
assert(
    #requests == 2 and requests[2] == RAW .. "3.5.5/Makefile",
    "the release page, then the Makefile, and nothing else: " .. table.concat(requests, " ")
)

info = install("3.5.12")
assert(info.version == "3.5.12", tostring(info.version))

info = install("3.6.0-rc.0")
assert(info.version == "3.6.0-rc.0", tostring(info.version))
assert(#requests == 3 and requests[3] == RAW .. "3.6.0-rc.0/tests/robustness/makefile.mk", table.concat(requests, " "))

assert(install("3.6.0-alpha.0") == nil)
assert(
    #printed == 1 and string.find(printed[1], "etcd 3.6.0-alpha.0 has no failpoint build", 1, true),
    table.concat(printed, "\n")
)

info = install("3.7.4")
assert(info.version == "3.7.4", tostring(info.version))
assert(#requests == 3 and requests[3] == RAW .. "3.7.4/tests/robustness/Makefile", table.concat(requests, " "))

-- A release that does not exist is named as such, before its Makefile is looked for.
assert(install("9.9.9") == nil)
assert(
    #printed == 1 and string.find(printed[1], "there is no etcd release 9.9.9", 1, true),
    table.concat(printed, "\n")
)
assert(#requests == 1, table.concat(requests, " "))
