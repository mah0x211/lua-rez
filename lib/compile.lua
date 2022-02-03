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
local random = math.random
local concat = table.concat
local find = string.find
local format = string.format
local ipairs = ipairs
local rep = string.rep
local tostring = tostring
local type = type
local errmap = require('rez.errmap')
local loadstring = require('loadchunk').string

local function end_op()
    return 'end'
end

local function else_op()
    return 'else'
end

local function elseif_op(expr)
    return format('elseif %s then', expr)
end

local function if_op(expr)
    return format('if %s then', expr)
end

local function while_op(expr)
    return format('while %s do', expr)
end

local function for_op(expr)
    return format('for %s do', expr)
end

local function code_op(expr)
    return expr or ''
end

local function break_op(expr)
    if expr then
        return format('if %s then break end', expr)
    end
    return 'break'
end

local function put_op(expr, bid, escfn_name)
    if escfn_name then
        return format('B%s[#B%s + 1] = %s(%s)', bid, bid, escfn_name, expr)
    end
    return format('B%s[#B%s + 1] = %s', bid, bid, expr)
end

local function text_op(expr, bid)
    return format('B%s[#B%s + 1] = %s', bid, bid, expr)
end

local OPFUNC = {
    ['text'] = text_op,
    ['put'] = put_op,
    ['break'] = break_op,
    ['code'] = code_op,
    ['if'] = if_op,
    ['elseif'] = elseif_op,
    ['else'] = else_op,
    ['/if'] = end_op,
    ['for'] = for_op,
    ['/for'] = end_op,
    ['while'] = while_op,
    ['/while'] = end_op,
}

local BLOCKSTART_OP = {
    ['if'] = true,
    ['for'] = true,
    ['while'] = true,
}

local BLOCKNEXT_OP = {
    ['elseif'] = true,
    ['else'] = true,
}

local function getpad(n)
    return rep(' ', 4 * n)
end

--- eval_expr
---@param expr table|nil
---@param did string data id
---@return string expr
local function eval_expr(expr, did)
    if type(expr) ~= 'table' then
        return expr
    end

    local dataname = 'D' .. did
    for i, v in ipairs(expr) do
        if v == '$' and (not expr[i - 1] or find(expr[i - 1], '[^%w%._]')) and
            (not expr[i + 1] or find(expr[i + 1], '^[^%w_]')) then
            expr[i] = dataname
        end
    end

    return concat(expr, '')
end

math.randomseed(os.time())

--- genid
---@return string
local function genid()
    return tostring(random(1000, 99999999))
end

--- compile
--- @param label string
--- @param tags table[]
--- @param env table
--- @return function fn
--- @return string err
local function compile(label, tags, env)
    if type(label) ~= 'string' then
        error('label must be a string', 2)
    elseif type(tags) ~= 'table' then
        error('tags must be a table', 2)
    elseif type(env) ~= 'table' then
        error('env must be a table', 2)
    end

    local fid = genid()
    local did = genid()
    local bid = genid()
    local ignore_after_break_op = false
    local blocknest = 1
    local padding = getpad(blocknest)
    local chunk = {
        format('local function F%s(D%s) local B%s = {};', fid, did, bid),
    }
    local escfn_name

    -- rename rez.escape function
    if env.rez.escape then
        escfn_name = 'ESC' .. genid()
        rawset(env, escfn_name, env.rez.escape)
        rawset(env.rez, 'escape', nil)
    end

    for i, tag in ipairs(tags) do
        local eval = OPFUNC[tag.op]
        if not eval then
            return nil, format('unsupported tag#%d: tag.op %q', i, tag.op)
        end

        local expr = eval_expr(tag.expr, did)

        -- manipulate indentation
        local pad = padding
        if eval == end_op then
            -- unnesting
            blocknest = blocknest - 1
            padding = getpad(blocknest)
            pad = padding
            -- uncomment
            ignore_after_break_op = false
        elseif BLOCKNEXT_OP[tag.op] then
            -- temporary unnesting
            pad = getpad(blocknest - 1)
            -- uncomment
            ignore_after_break_op = false
        end

        -- gen code
        local code = eval(expr, bid, escfn_name)
        if ignore_after_break_op then
            code = pad .. '-- ' .. code .. ' -- ignore after break_op'
        else
            code = pad .. code
        end
        chunk[#chunk + 1] = code

        -- manipulate indentation
        -- nest after block-start-op
        if BLOCKSTART_OP[tag.op] then
            blocknest = blocknest + 1
            padding = getpad(blocknest)
        end

        -- ignore any op after break_op expect block-end op
        if eval == break_op and not expr then
            ignore_after_break_op = true
        end
    end
    chunk[#chunk + 1] = padding .. format('return B%s', bid)
    chunk[#chunk + 1] = 'end'
    chunk[#chunk + 1] = format('return F%s', fid)

    -- compile
    local src = concat(chunk, '\n')
    local fn, err = loadstring(src, env, label)
    if err then
        return nil, errmap(label, tags, err)
    end

    return {
        run = fn(),
        env = env,
        tags = tags,
    }
end

return compile
