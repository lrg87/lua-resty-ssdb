 -- Lua client for https://github.com/ideawu/ssdb
 -- Copyright (c) 2015 Eleme, Inc.
 
local spp = require 'spp_lua'

-- Lua 5.1 unpack
-- Lua 5.2+ table.unpack
local unpack = unpack or table.unpack

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
    qpush           = 'string',
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


-- Connection

local Connection = {}
Connection.__index = Connection

function Connection.new(options)
    local self = setmetatable({}, Connection)
    local options = options or {}
    self.port = options.port or 8888
    self.host = options.host or '127.0.0.1'
    self.auth = options.auth
    self.timeout = options.timeout or 0

    self.sock = nil
    self.cmds = {}
    self.parser = spp:new()
    return self
end

function Connection.setkeepalive(self, ...)
    if not self.sock then
        return nil, 'socket not initialized'
    end
    return self.sock:setkeepalive(...)
end


function Connection.settimeout(self, ...)
    if not self.sock then
        return nil, 'socket not initialized'
    end
    return self.sock:settimeout(...)
end

function Connection.connect(self)
    local err

    self.sock, err = ngx.socket.tcp()

    if err and not sock then
        return sock, err
    end
    self.sock:settimeout(self.timeout)
    return self.sock:connect(self.host, self.port)
end

function Connection.close(self)
    local sock = self.sock
    self.parser:clear()
    self.sock = nil
    return sock:close()
end

function Connection.encode(self, args)
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

function Connection.send(self)
    local reqs = {}

    for _, cmd in pairs(self.cmds) do
        table.insert(reqs, self:encode(cmd))
    end
    return self.sock:send(table.concat(reqs))
end

function Connection.build(self, _type, data)
    return conversions[_type](data)
end

function Connection.recv(self)
    local ress = {}

    while #ress < #self.cmds do
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

function Connection.request(self)
    -- lazy connect
    if not self.sock then
        local ok, err = self:connect()
        if not ok then
            return ok, err
        end
    end

    -- send request
    local bytes, err = self:send()
    if not bytes then
        return bytes, err
    end

    -- recv response
    local ress, err = self:recv()
    if not ress then
        return ress, err
    end

    -- build values
    local list = {}

    for idx, res in pairs(ress) do
        local cmd = self.cmds[idx]
        local ok = table.remove(res, 1)

        local val
        local err
        if ok == 'ok' then
            local type = commands[cmd[1]]
            val = self:build(type, res)
        else
            err = ok
        end
        table.insert(list, {val, err})
    end

    -- clear commands
    for idx, _ in pairs(self.cmds) do
        self.cmds[idx] = nil
    end

    return list
end


-- Client
local Client = {}
Client.__index = Client

function Client.new(options)
    local self = setmetatable({}, Client)
    self.conn = Connection:new(options)
    self._pipeline_mode = false

    -- make methods for this instance
    for name, _ in pairs(commands) do
        Client[name] = function(...)
            -- queue request
            local args = {...}
            local reqs = {name}

            for i = 2, #args do
                table.insert(reqs, args[i])
            end

            table.insert(self.conn.cmds, reqs)
            -- send request
            if not self._pipeline_mode then
                return unpack(self.conn:request()[1])
            end
        end
    end

    return self
end

function Client.close(self)
    return self.conn:close()
end

function Client.start_pipeline(self)
    self._pipeline_mode = true
end

function Client.commit_pipeline(self)
    local list = self.conn:request()
    self._pipeline_mode = false
    return list
end

function Client.settimeout(self, ...)
    return self.conn:settimeout(...)
end

function Client.setkeepalive(self, ...)
    return self.conn:setkeepalive(...)
end

function Client.connect(self, ...)
    return self.conn:connect(...)
end

-- exports
return {
    newclient = function(options)
        return Client:new(options)
    end
}
