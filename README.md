lua-resty-ssdb
--------------

Lua client for https://github.com/ideawu/ssdb.

Exampple
--------

First, build [spp_lua](https://github.com/eleme/spp_lua):
and then add its path to lua's cpath:

```lua
package.cpath = package.cpath .. ';path/to/spp_lua/?.so'

local ssdb = require 'ssdb'
```

License
--------

Copyright (c) 2014 Eleme, Inc.
