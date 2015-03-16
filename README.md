lua-resty-ssdb
--------------

The fastest lua client for [ssdb](https://github.com/ideawu/ssdb) and nginx
(based on [lua-nginx-module](https://github.com/openresty/lua-nginx-module)).

Build
------

```bash
$ make
```

Usage
-----

Add its path to `package.path` and `package.cpath` for lua-nginx-module,
e.g. :

```
lua_package_path 'path/to/lua-resty-ssdb/?.lua;';
lua_package_cpath 'path/to/lua-resty-ssdb/?.so;';
```

API Reference
-------------

### Sample Usage

```lua
local ssdb = require 'ssdb'
local client = ssdb.newclient()
local res, err = client:set('k', 'v')
local res, err = client:get('k')
```

### Pipeline

```lua
client:start_pipeline()
client:set('k1', 'v1')
client:set('k2', 'v2')
client:set('k3', 'v3')
vals = client:commit_pipeline()
```

### Returns

- `err` is not `nil` on any errors.
- `res` is `nil` on any errors.

### Value Types

Values returned from commands can be found from
table `commands` in [ssdb.lua](ssdb.lua).

### Errors

All possible `err` values for all ssdb commands: 

```
'ok', 'not_found', 'server_error', 'client_error', 'timeout', 'connection refused'
```

### newclient(options)

To create a ssdb client:

```lua
local ssdb = require 'ssdb'
local client = ssdb.newclient()
```

options (with default values):

```lua
{
    host = '127.0.0.1',
    port = 8888,
    auth = nil,  -- currently not supported
    timeout = 0
}
```

### client:close()

Close from ssdb server.

### client:start_pipeline()

Start pipeline.

### client:commit_pipeline()

Commit pipeline to ssdb server, return table of multiple vals like `{res, err}`.

### client:cancel_pipeline()

Cancel current pipeline.

### client:settimeout(time)

Set the timeout value in milliseconds for subsequent socket operations, detail see 
[tcpsock:settimeout](http://wiki.nginx.org/HttpLuaModule#tcpsock:settimeout).

### client:setkeepalive(timeout, size)

See [tcpsock:setkeepalive](http://wiki.nginx.org/HttpLuaModule#tcpsock:setkeepalive).

`setkeepalive` can be used to make a long connection, e.g., a forever long long connection:

```lua
client:setkeepalive(0, 1)
```

### client:connect()

By default, ssdb is lazy connected, but method `connect` can be used to 
test if the server is alive, e.g.

```lua
ok, err = client.connect()
if not ok then
  ngx.log(ngx.ERR, err)
  return
end
```

Documentations
--------------

Detail docs for ssdb commands can be found at https://github.com/hit9/ssdb.api.docs.

License
--------

Copyright (c) 2015 Eleme, Inc.
