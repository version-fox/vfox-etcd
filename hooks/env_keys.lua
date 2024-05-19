local etcdUtils = require("etcd_utils")

--- Each SDK may have different environment variable configurations.
--- This allows plugins to define custom environment variables (including PATH settings)
--- Note: Be sure to distinguish between environment variable settings for different platforms!
--- @param ctx table Context information
--- @field ctx.path string SDK installation directory
function PLUGIN:EnvKeys(ctx)
    --- this variable is same as ctx.sdkInfo['plugin-name'].path
    local mainPath = ctx.path
    -- etcd install from source build
    if etcdUtils.is_dir(ctx.path .. "/etcd/bin") then
        mainPath = ctx.path .. "/etcd/bin"
    end
    return {
        {
            key = "PATH",
            value = mainPath
        },
    }
end