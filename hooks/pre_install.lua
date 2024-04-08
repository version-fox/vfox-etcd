-- local erlangUtils = require("erlang_utils")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local etcd_version = ctx.version    
    local download_url
    if RUNTIME.osType == "Linux" then
        download_url = "https://github.com/etcd-io/etcd/releases/download/v" .. etcd_version .. "/etcd-v" .. etcd_version .. "-" .. string.lower(RUNTIME.OS_TYPE) .. "-" .. string.lower(RUNTIME.archType) .. ".tar.gz"
    else
        download_url = "https://github.com/etcd-io/etcd/releases/download/v" .. etcd_version .. "/etcd-v" .. etcd_version .. "-" .. string.lower(RUNTIME.OS_TYPE) .. "-" .. string.lower(RUNTIME.archType) .. ".zip"
    end
    
    return {
        version = etcd_version,
        url = download_url
    }
end