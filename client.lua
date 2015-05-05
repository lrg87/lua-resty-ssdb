 -- Lua client for https://github.com/ideawu/ssdb
 -- Copyright (c) 2015 Eleme, Inc.

local spp = require 'resty.ssdb.spp_lua'

-- Lua 5.1 unpack
-- Lua 5.2+ table.unpack
local unpack = unpack or table.unpack
local tlen = rawlen or table.getn

-- conversions from buffer to lua type
local conversions = {
    number = function(t)
        return tonumber(t[1])
    end,

    string = function(t)
        return t[1]
    end,

    boolean = function(t)
        return tonumber(t[1]) ~= 0
    end,

    table = function(t)
        return t
    end
}

local commands = {
    set             = 'number',
    setx            = 'number',
    expire          = 'number',
    ttl             = 'number',
    setnx           = 'number',
    get             = 'string',
    getset          = 'string',
    del             = 'number',
    incr            = 'number',
    exists          = 'boolean',
    getbit          = 'number',
    setbit          = 'number',
    countbit        = 'number',
    substr          = 'string',
    strlen          = 'number',
    keys            = 'table',
    scan            = 'table',
    rscan           = 'table',
    multi_set       = 'number',
    multi_get       = 'table',
    multi_del       = 'number',
    hset            = 'number',
    hget            = 'string',
    hdel            = 'number',
    hincr           = 'number',
    hexists         = 'boolean',
    hsize           = 'number',
    hlist           = 'table',
    hrlist          = 'table',
    hkeys           = 'table',
    hgetall         = 'table',
    hscan           = 'table',
    hrscan          = 'table',
    hclear          = 'number',
    multi_hset      = 'number',
    multi_hget      = 'table',
    multi_hdel      = 'number',
    zset            = 'number',
    zget            = 'number',
    zdel            = 'number',
    zincr           = 'number',
    zexists         = 'boolean',
    zsize           = 'number',
    zlist           = 'table',
    zrlist          = 'table',
    zkeys           = 'table',
    zscan           = 'table',
    zrscan          = 'table',
    zrank           = 'number',
    zrrank          = 'number',
    zrange          = 'table',
    zrrange         = 'table',
    zclear          = 'number',
    zcount          = 'number',
    zsum            = 'number',
    zavg            = 'number',
    zremrangebyrank = 'number',
    zremrangebyscore= 'number',
    multi_zset      = 'number',
    multi_zget      = 'table',
    multi_zdel      = 'number',
    qsize           = 'number',
    qclear          = 'number',
    qfront          = 'string',
    qback           = 'string',
    qget            = 'string',
    qslice          = 'table',
    qpush           = 'number',
    qpush_front     = 'number',
    qpush_back      = 'number',
    qpop            = 'string',
    qpop_front      = 'string',
    qpop_back       = 'string',
    qlist           = 'table',
    qrlist          = 'table',
    dbsize          = 'number',
    info            = 'table',
    auth            = 'boolean'
}

-- Conn
local Conn = {}
Conn.__index = Conn

function Conn.new(options)
    local self = setmetatable({}, Conn)
    local options = options or {}

    self.port = options.port or 8888
    self.host = options.host or '127.0.0.1'
    self.auth = options.auth
    self.timeout = options.timeout or 1000

    self.sock = nil
    self.cmds = {}
    self.parser = spp.new()
    return self
end

function Conn.setkeepalive(self, ...)
    if not self.sock then
        return nil, 'socket not initialized'
    end
    return self.sock:setkeepalive(...)
end

function Conn.connect(self)
    local err

    self.sock, err = ngx.socket.tcp()

    if err and not sock then
        return sock, err
    end
    self.sock:settimeout(self.timeout)
    return self.sock:connect(self.host, self.port)
end

function Conn.close(self)
    local sock = self.sock
    self.parser:clear()
    self.sock = nil
    return sock:close()
end

function Conn.encode(self, args)
    local args = args or {}
    local reqs = {}

    for _, arg in pairs(args) do
        local len = string.len(tostring(arg))
        local req = string.format('%s\n%s\n', len, arg)
        table.insert(reqs, req)
    end
    table.insert(reqs, '\n')
    return table.concat(reqs)
end

function Conn.send(self, cmds)
    local reqs = {}
    for _, cmd in pairs(cmds) do
        table.insert(reqs, self:encode(cmd))
    end
    return self.sock:send(table.concat(reqs))
end

function Conn.recv(self, len)
    local ress = {}
    while tlen(ress) < len do
        while true do
            local line, err = self.sock:receive()
            if not line then
                if err == 'timeout' then
                    self:close()
                end
                return line, err
            end
            self.parser:feed(line .. '\n')
            if line == '' then
                break
            end
        end
        local res = self.parser:get()
        if res then
            table.insert(ress, res)
        end
    end
    return ress, err
end

function Conn.auth_(self, auth)
    local cmds = {{'auth', auth}}
    local bytes, err = self:send(cmds)
    if not bytes then
        return bytes, err
    end

    local ress, err = self:recv(tlen(cmds))
    if not ress then
        return ress, err
    end

    local list = self:cast(cmds, ress)
    assert(tlen(list) == 1)
    return unpack(list[1])
end

function Conn.cast(self, cmds, ress)
    local list = {}
    for idx, res in pairs(ress) do
        local cmd = cmds[idx]
        local status = table.remove(res, 1)
        local val, err
        if status == 'ok' then
            local type = commands[cmd[1]]
            val = conversions[type](res)
        else
            err = status
        end
        table.insert(list, {val, err})
    end
    return list
end

function Conn.cmd_push(self, name, args)
    local cmd = {name}
    for _, v in pairs(args) do
        table.insert(cmd, v)
    end
    return table.insert(self.cmds, cmd)
end

function Conn.cmd_clear(self)
    while tlen(self.cmds) > 0 do
        table.remove(self.cmds, 1)
    end
end

function Conn.request(self)
    -- lazy connect
    if not self.sock then
        local ok, err = self:connect()
        if not ok then
            return ok, err
        end

        -- make auth
        if self.auth then
            local ok, err = self:auth_(self.auth)
            if not ok then
                return ok, err
            end
        end
    end

    -- send request
    local bytes, err = self:send(self.cmds)
    if not bytes then
        return bytes, err
    end

    -- recv responses
    local ress, err = self:recv(tlen(self.cmds))
    if not ress then
        return ress, err
    end

    -- build values
    local list = self:cast(self.cmds, ress)
    self:cmd_clear()
    return list
end

-- Client
local Client = {}
Client.__index = Client

function Client.new(options)
    local self = setmetatable({}, Client)
    self.conn = Conn.new(options)
    self._pipeline_mode = false

    -- make methods
    for name, _ in pairs(commands) do
        Client[name] = function(self, ...)
            self.conn:cmd_push(name, {...})
            if not self._pipeline_mode then
                local list, err = self.conn:request()
                if not list then
                    return list, err
                end
                return unpack(list[1])
            end
        end
    end
    return self
end

function Client.setkeepalive(self, ...)
    return self.conn:setkeepalive(...)
end

function Client.connect(self, ...)
    return self.conn:connect(...)
end

function Client.close(self)
    return self.conn:close()
end

function Client.start_pipeline(self)
    self._pipeline_mode = true
end

function Client.commit_pipeline(self)
    self._pipeline_mode = false
    return self.conn:request()
end

function Client.cancel_pipeline(self)
    for idx, _ in pairs(self.conn.cmds) do
        self.conn.cmds[idx] = nil
    end
    self._pipeline_mode = false
end

-- exports
return {
    __version__ = '0.0.3',
    newclient = function(options)
        return Client.new(options)
    end
}
