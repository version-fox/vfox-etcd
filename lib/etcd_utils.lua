local http = require("http")

local etcd_utils = {}

function etcd_utils.get_etcd_release_verions()
    local resp, err = http.get({
        url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-etcd@main/assets/versions.txt"
    })
    local result = {}
    for version in string.gmatch(resp.body, '([^\n]+)') do
        table.insert(result, {
            version = version
        })
    end
    return result
end

function etcd_utils.get_sha256sums(etcd_version, file_name)
    local resp, err = http.get({
        url = "https://github.com/etcd-io/etcd/releases/download/v" .. etcd_version .. "/SHA256SUMS"
    })
    for line in string.gmatch(resp.body, '([^\n]+)') do
        local checksum, name = string.match(line, '(%w+)%s+(%S+)')
        if name == file_name then
            return checksum
        end
    end
end

function etcd_utils.is_dir(path)
    local status = os.execute("[ -d " .. path .. " ]")
    return status == 0
end


return etcd_utils