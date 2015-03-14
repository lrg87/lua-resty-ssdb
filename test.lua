-- Nginx config for http section:
--
--   lua_package_path 'path/to/lua-resty-ssdb/?.lua;;';
--   lua_package_cpath 'path/to/lua-resty-ssdb/?.so;;';
--
-- Nginx config for location section
--
--   access_by_lua_file path/to/lua-resty-ssdb/test.lua;
--
-- SSDB 127.0.0.1:8888

local ssdb = require 'ssdb'
local c = ssdb.newclient()

-- utils
local time_now = os.time()
local uk_cursor = 0

function uk()
    uk_cursor = uk_cursor + 1
    return (time_now .. uk_cursor)
end

function test_set()
    local ok, err = c:set(uk(), 'v')
    assert(ok == 1 and not err)
end

function test_get()
    local key = uk()
    c:set(key, 'v')
    local val, err = c:get(key)
    assert(val == 'v' and not err)
end

function test_setx()
    local key = uk()
    local val, err = c:setx(key, 'v', 1)
    assert (val == 1 and not err)
    local val, err = c:get(key)
    assert(val == 'v' and not err)
    os.execute('sleep 1.5')
    local val, err = c:get(key)
    assert(not val and err == 'not_found')
end

function test_expire()
    local key = uk()
    c:set(key, 'v')
    local val, err = c:expire(key, 1)
    assert(val == 1 and not err)
    os.execute('sleep 1.5')
    local val, err = c:get(key)
    assert(not val and err == 'not_found')
end

function test_ttl()
    local key = uk()
    c:set(key, 'v')
    local val, err = c:ttl(key)
    assert(val == -1 and not err)
end

function test_setnx()
    local key1 = uk()
    local key2 = uk()
    c:set(key1, 'v')
    local val, err = c:setnx(key1, 'v')
    assert(val == 0 and not err)
    local val, err = c:setnx(key2, 'v')
    assert(val == 1 and not err)
end

function test_get()
    local key = uk()
    c:set(key, 'v')
    local val, err = c:get(key)
    assert(val == 'v' and not err)
end

function test_getset()
    local key1, val1 = uk(), 'v1'
    local key2, val2 = uk(), 'v2'
    c:set(key1, val1)
    local val, err = c:getset(key1, val2)
    assert(val == val1 and not err)
    local val, err = c:getset(key2, val2)
    assert(val == nil and err == 'not_found')
end

function test_del()
    local key1, key2 = uk(), uk()
    c:set(key1, 'v')
    local val, err = c:del(key1)
    assert(val == 1 and not err)
    local val, err = c:get(key1)
    assert(val == nil and err == 'not_found')
    local val, err = c:del(key2)
    assert(val == 1 and not err)
end

function test_incr()
    local key = uk()
    local val, err = c:incr(key, 1)
    assert(val == 1 and not err)
    local val, err = c:incr(key, 2)
    assert(val == 3 and not err)
    local val, err = c:incr(key, 3)
    assert(val == 6 and not err)
end

-- Run tests
test_set()
test_get()
test_setx()
test_expire()
test_ttl()
test_setnx()
test_get()
test_getset()
test_del()
test_incr()
