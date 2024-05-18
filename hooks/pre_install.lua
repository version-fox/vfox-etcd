local etcdUtils = require("etcd_utils")

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local etcd_version = ctx.version
    local file, download_url

    -- Build etcd with failpoints: https://github.com/etcd-io/etcd/tree/main/tests/robustness#running-locally
    BUILD_WITH_FAILPOINT = os.getenv("BUILD_WITH_FAILPOINT") or "false"
    if BUILD_WITH_FAILPOINT == "yes" and RUNTIME.osType ~= "windows" then
        download_url = "https://github.com/etcd-io/etcd/archive/refs/tags/v" .. etcd_version .. ".zip"
        print("etcd download url: " .. download_url)
        return {
            version = etcd_version
        }
    end

    if RUNTIME.osType == "linux" then
        file = "etcd-v" .. etcd_version .. "-" .. string.lower(RUNTIME.osType) .. "-" .. string.lower(RUNTIME.archType) .. ".tar.gz"
    else
        file = "etcd-v" .. etcd_version .. "-" .. string.lower(RUNTIME.osType) .. "-" .. string.lower(RUNTIME.archType) .. ".zip"
    end
    local checksum = etcdUtils.get_sha256sums(etcd_version, file)
    download_url = "https://github.com/etcd-io/etcd/releases/download/v" .. etcd_version .. "/" .. file
    print("etcd download url: " .. download_url)

    return {
        version = etcd_version,
        url = download_url,
        sha256 = checksum
    }
end