--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local error = error
local format = string.format
local next = next
local setmetatable = setmetatable
local type = type
local pairs = pairs
local pcall = pcall
local compile = require('rez.compile')
local newfenv = require('rez.newfenv')
local parse = require('rez.parse')
local nilobj = require('rez.nilobj')
local errmap = require('rez.errmap')
local seal = require('rez.seal')
local concat = require('rez.concat')
local nilobj_enable = nilobj.enable
local nilobj_disable = nilobj.disable

--- render
--- @param rez Rez
--- @param name string
--- @return string res
--- @return string err
local function render(rez, name)
    -- get target template
    local target = rez.tmpl[name]
    if not target then
        return nil, format('template %q not found', name)
    end

    -- prevent recursive rendering
    local callstack = rez.callstack
    if callstack[name] then
        error(format('cannot render template %q recursively', name), 3)
    end

    -- create context
    local ctx = {}
    callstack[name] = ctx
    callstack[#callstack + 1] = name

    -- run
    local data = rez.data
    local ok, res = pcall(target.run, data)

    -- remove context
    callstack[name] = nil
    callstack[#callstack] = nil

    -- apply layout
    if ctx.layout then
        if ok then
            data[ctx.layout.varname] = concat(res)
        else
            data[ctx.layout.varname] = errmap(name, target.tags, res)
        end
        return render(rez, ctx.layout.name)
    end

    if not ok then
        return nil, errmap(name, target.tags, res)
    end

    return concat(res)
end

--- rez_render
--- @param rez Rez
--- @param name string
--- @return string
local function rez_render(rez, name)
    if type(name) ~= 'string' then
        error('name must be string', 2)
    end

    local res, err = render(rez, name)
    return res or err
end

--- rez_layout
--- @param rez Rez
--- @param name string
--- @param varname string
local function rez_layout(rez, name, varname)
    if type(name) ~= 'string' then
        error('name must be string', 2)
    elseif type(varname) ~= 'string' then
        error('varname must be string', 2)
    elseif not rez.tmpl[name] then
        error(format('layout template %q not found', name), 2)
    end

    -- prevent recursive rendering
    local callstack = rez.callstack
    if callstack[name] then
        error(format('cannot apply layout %q recursively', name), 2)
    end

    -- get current context
    local ctx = callstack[callstack[#callstack]]
    if ctx.layout then
        error('layout cannot be applied twice', 2)
    end
    -- add layout info
    ctx.layout = {
        name = name,
        varname = varname,
    }
end

--- table_copy
--- @param tbl table
--- @return table|nil
local function table_copy(tbl)
    local newtbl = {}

    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            newtbl[k] = table_copy(v)
        else
            newtbl[k] = v
        end
    end

    -- return non-empty table
    if next(newtbl) then
        return newtbl
    end
end

--- new_env
--- @param rez Rez
--- @return table fenv
local function new_env(rez)
    -- setup environment
    local fenv = newfenv()
    if type(rez.env) == 'table' then
        for k, v in pairs(table_copy(rez.env) or {}) do
            fenv[k] = v
        end
    end
    -- add rez functions
    fenv.rez = {
        render = function(name)
            return rez_render(rez, name)
        end,
        layout = function(name, varname)
            return rez_layout(rez, name, varname)
        end,
    }

    return seal(fenv)
end

--- @class Rez
--- @field tmpl table
--- @field callstack table
--- @field env table
local Rez = {}
Rez.__index = Rez

--- render
--- @param name string
--- @param data table
--- @return string res
--- @return string err
function Rez:render(name, data)
    if type(name) ~= 'string' then
        error('name must be string', 2)
    elseif data ~= nil and type(data) ~= 'table' then
        error('data must be table', 2)
    end

    self.callstack = {}
    self.data = data or {}
    nilobj_enable()
    local res, err = render(self, name)
    nilobj_disable()
    self.callstack = nil
    self.data = nil

    return res, err
end

--- del
--- @param name string
--- @return boolean ok
function Rez:del(name)
    if type(name) ~= 'string' then
        error('name must be a string', 2)
    elseif not self.tmpl[name] then
        return false
    end

    self.tmpl[name] = nil

    return true
end

--- add
--- @param name string
--- @param str string
--- @return boolean ok
--- @return string err
function Rez:add(name, str)
    if type(name) ~= 'string' then
        error('name must be string', 2)
    elseif type(str) ~= 'string' then
        error('str must be string', 2)
    end

    local tags, err = parse(str)
    if err then
        return false, err
    end

    -- compile
    local tmpl, cerr = compile(name, tags, new_env(self))
    if cerr then
        return false, cerr
    end
    self.tmpl[name] = tmpl

    return true
end

--- new
--- @param opts table
--- @return Rez
local function new(opts)
    opts = opts or {}
    -- check arguments
    if type(opts) ~= 'table' then
        error('opts must be table', 2)
    elseif opts.env ~= nil and type(opts.env) ~= 'table' then
        error('opts.env must be table', 2)
    end

    return setmetatable({
        tmpl = {},
        env = opts.env,
    }, Rez)
end

return {
    new = new,
}
