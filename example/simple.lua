local ssdb = require('ssdb').newclient()

ok, err = ssdb:connect()

if not ok then
    ngx.log(ngx.ERR, err)
    return 
end

res, err = ssdb:set('k', 'v')

if not res then
    ngx.log(ngx.ERR, err)
else
    ngx.log(ngx.INFO, res)
end
