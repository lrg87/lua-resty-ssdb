local ssdb = require('ssdb').newclient()
local unpack = unpack or table.unpack  -- 5.1/5.2+ compact

ssdb:start_pipeline()
ssdb:set('k1', 'v1')
ssdb:set('k2', 'v2')
ssdb:set('k3', 'v3')
vals = ssdb:commit_pipeline()

for _, val in pairs(vals) do
    local res, err = unpack(val)
    if not res then
        ngx.log(ngx.ERR, err)
    else
        ngx.log(ngx.INFO, res)
    end
end
