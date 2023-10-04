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
local format = string.format
local next = next
local getmetatable = debug.getmetatable
local setmetatable = setmetatable
local tostring = tostring
local type = type
local pairs = pairs
local pcall = pcall
local fatalf = require('error').fatalf
local compile = require('rez.compile')
local newfenv = require('rez.newfenv')
local parse = require('rez.parse')
local nilobj = require('rez.nilobj')
local errmap = require('rez.errmap')
local seal = require('rez.seal')
local concat = require('rez.concat')
local escape = require('rez.escape')
local nilobj_enable = nilobj.enable
local nilobj_disable = nilobj.disable

--- is_callable
--- @param v any
--- @return boolean ok
local function is_callable(v)
    if type(v) == 'function' then
        return true
    end

    local mt = getmetatable(v)
    if type(mt) == 'table' then
        return type(mt.__call) == 'function'
    end

    return false
end

--- default_loader
--- @return boolean ok
--- @return any err
local function DEFAULT_LOADER()
    return false
end

--- render
--- @param rez Rez
--- @param name string
--- @return string res
--- @return string err
local function render(rez, name)
    -- get target template
    local target = rez.tmpl[name]
    if not target then
        local ok, err = rez.loader(rez, name)
        if ok then
            target = rez.tmpl[name]
        elseif err then
            fatalf(2, 'cannot load template %q: %s', name, err)
        end

        if not target then
            return nil, format('template %q not found', name)
        end
    end

    -- prevent recursive rendering
    local callstack = rez.callstack
    if callstack[name] then
        fatalf(3, 'cannot render template %q recursively', name)
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
            data[ctx.layout.varname] = errmap(name, target.srcmap, res)
        end
        return render(rez, ctx.layout.name)
    end

    if not ok then
        return nil, errmap(name, target.srcmap, res)
    end

    return concat(res)
end

--- rez_render
--- @param rez Rez
--- @param name string
--- @return string
local function rez_render(rez, name)
    if type(name) ~= 'string' then
        fatalf(2, 'name must be string')
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
        fatalf(2, 'name must be string')
    elseif type(varname) ~= 'string' then
        fatalf(2, 'varname must be string')
    elseif not rez.tmpl[name] then
        local ok, err = rez.loader(rez, name)
        if not ok then
            if err then
                fatalf(2, 'cannot apply layout %q %s', name, err)
            else
                fatalf(2, 'layout template %q not found', name)
            end
        end
    end

    -- prevent recursive rendering
    local callstack = rez.callstack
    if callstack[name] then
        fatalf(2, 'cannot apply layout %q recursively', name)
    end

    -- get current context
    local ctx = callstack[callstack[#callstack]]
    if ctx.layout then
        fatalf(2, 'layout cannot be applied twice')
    end
    -- add layout info
    ctx.layout = {
        name = name,
        varname = varname,
    }
end

--- table_copy
--- @param tbl table
--- @return table?
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
    -- export escape functions
    for k, v in pairs(escape) do
        fenv.rez['escape_' .. k] = v
    end

    -- add rez.escape function to escape the output strings
    -- this function will be renamed by compiler
    fenv.rez.escape_html = is_callable(rez.escape) and rez.escape or escape.html

    return seal(fenv)
end

--- @class Rez
--- @field tmpl table
--- @field callstack table
--- @field curly boolean
--- @field escape function
--- @field loader function
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
        fatalf(2, 'name must be string')
    elseif data ~= nil and type(data) ~= 'table' then
        fatalf(2, 'data must be table')
    end

    self.callstack = {}
    self.data = data or {}
    local mt = nilobj_enable()
    local ok, res, err = pcall(render, self, name)
    nilobj_disable(mt)
    self.callstack = nil
    self.data = nil

    if not ok then
        return nil, res
    end

    return res, err
end

--- clear
function Rez:clear()
    self.tmpl = {}
end

--- del
--- @param name string
--- @return boolean ok
function Rez:del(name)
    if type(name) ~= 'string' then
        fatalf(2, 'name must be string')
    elseif not self.tmpl[name] then
        return false
    end

    self.tmpl[name] = nil

    return true
end

--- exists
--- @param name string
--- @return boolean ok
function Rez:exists(name)
    if type(name) ~= 'string' then
        fatalf(2, 'name must be string')
    end
    return self.tmpl[name] ~= nil
end

--- add
--- @param name string
--- @param str string
--- @return boolean ok
--- @return any err
function Rez:add(name, str)
    if type(name) ~= 'string' then
        fatalf(2, 'name must be string')
    elseif type(str) ~= 'string' then
        fatalf(2, 'str must be string')
    end

    local tags, err = parse(str, self.curly)
    if err then
        return false,
               format('failed to parse %q template: %s', name, tostring(err))
    end

    -- compile
    local tmpl, cerr = compile(name, tags, new_env(self))
    if cerr then
        return false, format('failed to compile %q template: %s', name, cerr)
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
        fatalf(2, 'opts must be table')
    elseif opts.env ~= nil and type(opts.env) ~= 'table' then
        fatalf(2, 'opts.env must be table')
    elseif opts.curly ~= nil and type(opts.curly) ~= 'boolean' then
        fatalf(2, 'opts.curly must be boolean')
    elseif opts.escape ~= nil and not is_callable(opts.escape) then
        fatalf(2, 'opts.escape must be callable value')
    elseif opts.loader ~= nil and not is_callable(opts.loader) then
        fatalf(2, 'opts.loader must be callable value')
    end

    return setmetatable({
        tmpl = {},
        env = opts.env,
        curly = opts.curly,
        escape = opts.escape,
        loader = opts.loader or DEFAULT_LOADER,
    }, Rez)
end

return {
    new = new,
}
