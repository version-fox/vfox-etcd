local etcdUtils = require("etcd_utils")

--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    return etcdUtils.get_etcd_release_verions()
end