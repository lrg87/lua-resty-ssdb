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
local pack = table.pack or pack
local unpack = table.unpack or unpack

local time_now = os.time()
local key_cursor = 0

function uk()
    key_cursor = key_cursor + 1
    return (time_now .. key_cursor)
end

function table.eql(a, b)
    if #a ~= #b then
        return false
    end

    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end
    return true
end

function longs(length)
    local t = {}
    for i = 1, length do 
        table.insert(t, 'v')
    end
    return table.concat(t)
end

-- cases
function test_set()
    local ok, err = c:set(uk(), 'v')
    assert(ok == 1 and not err)
end

function test_get()
    local key = uk()
    c:set(key, 'v')
    local res, err = c:get(key)
    assert(res == 'v' and not err)
end

function test_setx()
    local key = uk()
    local res, err = c:setx(key, 'v', 1)
    assert (res == 1 and not err)
    local res, err = c:get(key)
    assert(res == 'v' and not err)
    os.execute('sleep 1.5')
    local res, err = c:get(key)
    assert(not res and err == 'not_found')
end

function test_expire()
    local key = uk()
    c:set(key, 'v')
    local res, err = c:expire(key, 1)
    assert(res == 1 and not err)
    os.execute('sleep 1.5')
    local res, err = c:get(key)
    assert(not res and err == 'not_found')
end

function test_ttl()
    local key = uk()
    c:set(key, 'v')
    local res, err = c:ttl(key)
    assert(res == -1 and not err)
end

function test_setnx()
    local key1 = uk()
    local key2 = uk()
    c:set(key1, 'v')
    local res, err = c:setnx(key1, 'v')
    assert(res == 0 and not err)
    local res, err = c:setnx(key2, 'v')
    assert(res == 1 and not err)
end

function test_get()
    local key = uk()
    c:set(key, 'v')
    local res, err = c:get(key)
    assert(res == 'v' and not err)
end

function test_getset()
    local key1, val1 = uk(), 'v1'
    local key2, val2 = uk(), 'v2'
    c:set(key1, val1)
    local res, err = c:getset(key1, val2)
    assert(res == val1 and not err)
    local res, err = c:getset(key2, val2)
    assert(res == nil and err == 'not_found')
end

function test_del()
    local key1, key2 = uk(), uk()
    c:set(key1, 'v')
    local res, err = c:del(key1)
    assert(res == 1 and not err)
    local res, err = c:get(key1)
    assert(res == nil and err == 'not_found')
    local res, err = c:del(key2)
    assert(res == 1 and not err)
end

function test_incr()
    local key = uk()
    local res, err = c:incr(key, 1)
    assert(res == 1 and not err)
    local res, err = c:incr(key, 2)
    assert(res == 3 and not err)
    local res, err = c:incr(key, 3)
    assert(res == 6 and not err)
end

function test_exists()
    local key = uk()
    local res, err = c:exists(key)
    assert(res == false and not err)
    c:set(key, 'v')
    local res, err = c:exists(key)
    assert(res == true and not err)
end

function test_getbit()
    local key = uk()
    c:set(key, 'val')
    local res, err = c:getbit(key, 2)
    assert(res == 1 and not err)
    local res, err = c:getbit(key, 1000)
    assert(res == 0 and not err)
end

function test_setbit()
    local key = uk()
    c:set(key, 'val')
    local res, err = c:setbit(key, 2, 0)
    assert(res == 1 and not err)
    local res, err = c:get(key)
    assert(res == 'ral' and not err)
end

function test_countbit()
    local key = uk()
    c:set(key, 'val')
    local res, err = c:countbit(key)
    assert(res == 12 and not err)
end

function test_substr()
    local key = uk()
    c:set(key, 'hello world')
    local res, err = c:substr(key, 6, 10)
    assert(res == 'world' and not err)
end

function test_strlen()
    local key, val = uk(), 'val'
    c:set(key, val)
    local res, err = c:strlen(key)
    assert(res == string.len(val) and not err)
end

function test_keys_scan_rscan()
    local key_ = uk() .. 'keys_scan_rscan'
    local key1, val1 = key_ .. 'k1', 'v1'
    local key2, val2 = key_ .. 'k2', 'v2'
    c:multi_set(key1, val1, key2, val2)
    local res, err = c:keys(key_, key2, 2)
    assert(table.eql(res, {key1, key2}) and not err)
    local res, err = c:scan(key_, key2, 2)
    assert(table.eql(res, {key1, val1, key2, val2}) and not err)
    local res, err = c:rscan(key2, key1, 2)
    assert(table.eql(res, {key1, val1}) and not err)
end

function test_multi_set_get_del()
    local key1, val1 = 'k1', 'v1'
    local key2, val2 = 'k2', 'v2'
    local key3, val3 = 'k3', 'v3'
    local res, err = c:multi_set(key1, val1, key2, val2, key3, val3)
    assert(res == 3 and not err)
    local res, err = c:multi_get(key1, key2, key3)
    assert(table.eql(res, {key1, val1, key2, val2, key3, val3}) and not err)
    local res, err = c:multi_del(key1, key2, key3)
    assert(res == 3 and not err)
    assert(not c:exists(key1))
    assert(not c:exists(key2))
    assert(not c:exists(key3))
end

function test_hash()
    local hash = uk() .. 'hash'
    local hkey, hval = uk(), 'v'
    local res, err = c:hset(hash, hkey, hval)
    assert(res == 1 and not err)
    local res, err = c:hget(hash, hkey)
    assert(res == hval and not err)
    local res, err = c:hexists(hash, hkey)
    assert(res == true and not err)
    local res, err = c:hsize(hash, hkey)
    assert(res == 1 and not err)
    local res, err = c:hdel(hash, hkey)
    assert(res == 1 and not err)
    local res, err = c:hexists(hash, hkey)
    assert(res == false and not err)
    local hkey, hval = uk(), 1
    assert(c:hset(hash, hkey, hval) == 1)
    local res, err = c:hincr(hash, hkey, hval)
    assert(res == hval + 1 and not err)
end

function test_bigstr()
    local key, val = uk(), longs(65535 * 3)
    local res, err = c:set(key, val)
    assert(res == 1 and not err)
    assert(c:get(key) == val)
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
test_exists()
test_getbit()
test_setbit()
test_countbit()
test_substr()
test_strlen()
test_keys_scan_rscan()
test_multi_set_get_del()
test_bigstr()
test_hash()
