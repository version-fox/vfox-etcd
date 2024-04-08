--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
function PLUGIN:PostInstall(ctx)
    --- ctx.rootPath SDK installation directory
    -- use ENV OTP_COMPILE_ARGS to control compile behavior
    local sdkInfo = ctx.sdkInfo['etcd']
    local path = sdkInfo.path
    print("etcd installed path: " .. path)
end