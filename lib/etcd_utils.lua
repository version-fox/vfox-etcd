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

return etcd_utils