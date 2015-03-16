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
    local hash_ = uk()
    local hash = hash_ .. 'hash'
    -- hset/hget/hsize/hexists/hdel
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
    -- multi_h*
    local hkey1, hval1 = uk(), 'v1'
    local hkey2, hval2 = uk(), 'v2'
    local hkey3, hval3 = uk(), 'v3'
    local hkey4, hval4 = uk(), 'v4'
    local res, err = c:multi_hset(hash, hkey1, hval1, hkey2, hval2,
    hkey3, hval3, hkey4, hval4)
    assert(res == 4 and not err)
    assert(c:hsize(hash) == 4)
    local res, err = c:multi_hget(hash, hkey1, hkey2)
    assert(table.eql(res, {hkey1, hval1, hkey2, hval2}) and not err)
    local res, err = c:multi_hdel(hash, hkey3, hkey4)
    assert(res == 2 and not err)
    -- hlist/hrlist/hscan/hrscan/hgetall/hkeys/hclear
    local res, err = c:hlist(hash_, hash, 1)
    assert(table.eql(res, {hash}) and not err)
    local res, err = c:hrlist(hash, hash_, 1)
    assert(table.eql(res, {}) and not err)
    local res, err = c:hkeys(hash, '', '', -1)
    assert(table.eql(res, {hkey1, hkey2}) and not err)
    local res, err = c:hscan(hash, '', '', -1)
    assert(table.eql(res, {hkey1, hval1, hkey2, hval2}) and not err)
    local res, err = c:hrscan(hash, '', '', 1)
    assert(table.eql(res, {hkey2, hval2}) and not err)
    local res, err = c:hgetall(hash)
    assert(table.eql(res, {hkey1, hval1, hkey2, hval2}) and not err)
    local res, err = c:hclear(hash)
    assert(res == 2 and not err)
    -- hincr
    local hkey, hval = uk(), 1
    assert(c:hset(hash, hkey, hval) == 1)
    local res, err = c:hincr(hash, hkey, 2)
    assert(res == hval + 2 and not err)
end

function test_zset()
    local zset_ = uk()
    -- zset/zget/zdel/zexists
    local zset = zset_ .. 'zset'
    local zkey, zval = uk(), 1
    local res, err = c:zset(zset, zkey, zval)
    assert(res == 1 and not err)
    local res, err = c:zget(zset, zkey)
    assert(res == zval and not err)
    local res, err = c:zincr(zset, zkey, 1)
    assert(res == 2 and not err)
    local res, err = c:zexists(zset, zkey)
    assert(res == true and not err)
    local res, err = c:zdel(zset, zkey)
    assert(res == 1 and not err)
    -- multi_z*
    local key1, val1 = uk(), 1
    local key2, val2 = uk(), 2
    local key3, val3 = uk(), 3
    local key4, val4 = uk(), 4
    local res, err = c:multi_zset(zset, key1, val1, key2, val2,
    key3, val3, key4, val4)
    assert(res == 4 and not err)
    local res, err = c:multi_zget(zset, key1, key2, key3, key4)
    assert(table.eql(res, {key1, tostring(val1), key2, tostring(val2),
    key3, tostring(val3), key4, tostring(val4)}) and not err)
    local res, err = c:multi_zdel(zset, key3, key4)
    assert(res == 2 and not err)
    -- zkeys*..
    local res, err = c:zsize(zset)
    assert(res == 2 and not err)
    local res, err = c:zlist(zset_, zset, -1)
    assert(table.eql(res, {zset}) and not err)
    local res, err = c:zrlist(zset, zset_, -1)
    assert(table.eql(res, {}) and not err)
    local res, err = c:zkeys(zset, '', '', '', -1)
    assert(table.eql(res, {key1, key2}) and not err)
    local res, err = c:zscan(zset, '', val1, val2, -1)
    assert(table.eql(res, {key1, tostring(val1), key2, tostring(val2)}) and not err)
    local res, err = c:zrscan(zset, '', val2, val1, -1)
    assert(table.eql(res, {key2, tostring(val2), key1, tostring(val1)}) and not err)
    local res, err = c:zrank(zset, key1)
    assert(res == 0 and not err)
    local res, err = c:zrrank(zset, key1)
    assert(res == 1 and not err)
    local res, err = c:zrange(zset, val1 - 1, -1)
    assert(table.eql(res, {key1, tostring(val1), key2, tostring(val2)}) and not err)
    local res, err = c:zrrange(zset, val1 - 1, -1)
    assert(table.eql(res, {key2, tostring(val2), key1, tostring(val1)}) and not err)
    local res, err = c:zcount(zset, val1, val2)
    assert(res == 2 and not err)
    local res, err = c:zsum(zset, val1, val2)
    assert(res == 3 and not err)
    local res, err = c:zavg(zset, val1, val2)
    assert(res == 1.5 and not err)
    local res, err = c:zremrangebyrank(zset, 0, 0)
    assert(res == 1 and not err)
    local res, err = c:zremrangebyscore(zset, 0, val2)
    assert(res == 1 and not err)
    assert(c:multi_zset(zset, key1, val1, key2, val2) == 2)
    local res, err = c:zclear(zset)
    assert(res == 2 and not err)
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
test_zset()
