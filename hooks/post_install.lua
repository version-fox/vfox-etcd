--- Extension point, called after PreInstall, can perform additional operations,
--- such as file operations for the SDK installation directory or compile source code
--- Currently can be left unimplemented!
function PLUGIN:PostInstall(ctx)
    --- ctx.rootPath SDK installation directory
    -- use ENV OTP_COMPILE_ARGS to control compile behavior
    local sdkInfo = ctx.sdkInfo['etcd']
    local path = sdkInfo.path
    print("etcd installed path: " .. path)

    BUILD_WITH_FAILPOINT = os.getenv("BUILD_WITH_FAILPOINT") or "false"
    if BUILD_WITH_FAILPOINT == "true" and RUNTIME.osType ~= "windows" then
        -- Build etcd with failpoints:
        local install_cmd = "cd " .. path .. " && git clone https://github.com/etcd-io/etcd.git . && make gofail-enable && make build"
        local status = os.execute(install_cmd)
        if status ~= 0 then
            error("etcd build with failpoint, please check the stdout for details.")
        end
    end
end