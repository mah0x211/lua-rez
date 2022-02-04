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
local type = type
local byte = string.byte
local find = string.find
local format = string.format
local gsub = string.gsub
local sub = string.sub
local match = string.match

--- trim
--- @param str string
--- @return string
local function trim(str)
    if find(str, '^%s+$') then
        return ' '
    end
    return match(str, '^%s*(.+)%s*$')
end

--- count lineno and position
--- @param txt string
--- @param head integer
--- @return integer lineno
--- @return integer column
local function linenocol(txt, head)
    local str = sub(txt, 1, head)
    local ohead = head
    local lineno = 1
    local pos = 0

    -- count lineno
    head = find(str, '\n', pos, true)
    while head do
        pos = head
        lineno = lineno + 1
        head = find(str, '\n', head + 1, true)
    end
    pos = ohead - pos

    return lineno, pos
end

local DISALLOWED_KEYWORDS = {
    ['self'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['for'] = true,
    ['function'] = true,
    ['goto'] = true,
    ['nil'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['until'] = true,
    ['while'] = true,
}

local BACKSLASH = byte('\\')

--- tokenize
--- @param expr string
--- @return table token
--- @return string err
local function tokenize(expr)
    local token = {}
    local pos = 1
    local head, tail = find(expr, '[^_%w]', pos)

    while head do
        if pos < head then
            -- verify left token
            local left_token = sub(expr, pos, head - 1)
            -- contains disallowed keywords
            if DISALLOWED_KEYWORDS[left_token] then
                return nil,
                       format('contains disallowed keywords %q', left_token)
            end
            token[#token + 1] = trim(left_token)
        end

        -- check symbol
        local sym = sub(expr, head, head)
        local is_literal = false

        if sym == '.' then
            -- treat multiple dots as a single symbol
            head, tail = find(expr, '%.+', head)
            sym = sub(expr, head, tail)
        elseif sym == '<' and sub(expr, head + 1, head + 1) == '<' then
            tail = tail + 1
            sym = '<<'
        elseif sym == '<' and sub(expr, head + 1, head + 1) == '=' then
            tail = tail + 1
            sym = '<='
        elseif sym == '>' and sub(expr, head + 1, head + 1) == '>' then
            tail = tail + 1
            sym = '>>'
        elseif sym == '>' and sub(expr, head + 1, head + 1) == '=' then
            tail = tail + 1
            sym = '>='
        elseif sym == '=' and sub(expr, head + 1, head + 1) == '=' then
            tail = tail + 1
            sym = '=='
        elseif sym == '~' and sub(expr, head + 1, head + 1) == '=' then
            tail = tail + 1
            sym = '~='
        elseif sym == '/' and sub(expr, head + 1, head + 1) == '/' then
            tail = tail + 1
            sym = '//'
        elseif sym == '"' or sym == "'" then
            is_literal = true
        elseif sym == '[' then
            local bhead, btail = find(expr, '=*%[', head + 1)
            if bhead then
                is_literal = true
                tail = btail
                sym = sub(expr, head, tail)
            end
        end

        if is_literal then
            -- skip literal token
            -- lookup quoted pair
            local pair_sym = gsub(sym, '%[', ']')
            local phead, ptail = find(expr, pair_sym, tail + 1, true)

            while phead do
                -- found symbol and it is not escaped by '\'
                if byte(expr, phead - 1) ~= BACKSLASH then
                    break
                end
                phead, ptail = find(expr, pair_sym, phead + 1, true)
            end

            if not phead then
                return nil, format('literal token is not closed by %q', sym)
            end
            tail = ptail
            token[#token + 1] = sub(expr, head, tail)
        else
            token[#token + 1] = sym
        end

        pos = tail + 1
        head, tail = find(expr, '[^_%w]', pos)
    end

    if pos <= #expr then
        local right_token = sub(expr, pos)
        -- contains disallowed keywords
        if DISALLOWED_KEYWORDS[right_token] then
            return nil, format('contains disallowed keywords %q', right_token)
        end
        token[#token + 1] = right_token
    end

    return token
end

local NO_EXPR_REQUIRED = {
    ['else'] = true,
    ['/if'] = true,
    ['/for'] = true,
    ['/while'] = true,
}

--- parse_expr
--- @param tag_suffix string
--- @param tag table
--- @param txt string
--- @param op_tail integer
--- @return integer pos
--- @return string err
--- @return table tag
local function parse_expr(tag_suffix, tag, txt, op_tail)
    -- parse closing characters
    local expr_head = op_tail
    local expr_tail, tail = find(txt, tag_suffix, expr_head)
    if not expr_tail then
        return nil,
               format("invalid tag at %d:%d: not closed by '%s'", tag.lineno,
                      tag.linecol, sub(tag_suffix, #tag_suffix - 1))
    end
    tag.tail = tail + 1

    -- trim right newline character
    if sub(txt, tail - 2, tail - 2) == '-' then
        tag.trim_right = true
    end

    -- extract expression
    if expr_head < expr_tail then
        local expr = sub(txt, expr_head, expr_tail - 1)
        -- not only spaces
        if not find(expr, '^%s*$') then
            if NO_EXPR_REQUIRED[tag.op] then
                return nil,
                       format(
                           'invalid tag at %d:%d: opcode %q cannot be declared with an expression',
                           tag.lineno, tag.linecol, tag.op)
            end

            -- verify
            local token, err = tokenize(trim(expr))
            if err then
                return nil, format('invalid tag at %d:%d: %s', tag.lineno,
                                   tag.linecol, err)
            end

            tag.expr = token
        end
    end

    return tail + 1, nil, tag
end

-- 'true' must be paired with a 'end' tag
local CLOSE_OP_REQUIRED = {
    ['code'] = false,
    ['break'] = false,
    ['elseif'] = false,
    ['else'] = false,
    ['if'] = true,
    ['for'] = true,
    ['while'] = true,
}

--- parse_op
--- @param tag_suffix string
--- @param tag table
--- @param txt string
--- @param op_head integer
--- @return integer pos
--- @return string err
--- @return table tag
local function parse_op(tag_suffix, tag, txt, op_head)
    -- parse opcode
    local op_tail = find(txt, '[^a-z]', op_head)
    if not op_tail then
        return nil, format("invalid tag at %d:%d: opcode not declared",
                           tag.lineno, tag.linecol)
    end

    -- verify opcode
    local op = sub(txt, op_head, op_tail - 1)
    local delimiter = sub(txt, op_tail, op_tail)
    if delimiter ~= ' ' and delimiter ~= '-' and delimiter ~= '?' then
        return nil,
               format("invalid tag at %d:%d: unknown opcode %q", tag.lineno,
                      tag.linecol, sub(txt, op_head, op_tail))
    elseif CLOSE_OP_REQUIRED[op] == nil then
        return nil, format("invalid tag at %d:%d: unknown opcode %q",
                           tag.lineno, tag.linecol, op)
    end

    tag.op = op
    if tag.end_op then
        if not CLOSE_OP_REQUIRED[op] then
            return nil,
                   format(
                       "invalid tag at %d:%d: opcode %q does not support a closing tag",
                       tag.lineno, tag.linecol, op)
        end
        tag.op = '/' .. op
    elseif CLOSE_OP_REQUIRED[op] then
        tag.close_op = '/' .. op
    end

    return parse_expr(tag_suffix, tag, txt, op_tail)
end

--- parse_put_op
--- @param tag_suffix string
--- @param tag table
--- @param txt string
--- @param op_head integer
--- @return integer pos
--- @return string err
--- @return table tag
local function parse_put_op(tag_suffix, tag, txt, op_head)
    tag.op = 'put'
    return parse_expr(tag_suffix, tag, txt, op_head)
end

local ESCAPE_TEXT_EXPR = {
    ['\n'] = '\\n',
    ['\''] = '\\\'',
    ['\\'] = '\\\\',
}

--- read template context
--- @param txt string
--- @param curly boolean
--- @return table[] tags
--- @return string err
local function parse(txt, curly)
    if type(txt) ~= 'string' then
        error('txt must be string', 2)
    elseif curly ~= nil and type(curly) ~= 'boolean' then
        error('curly must be boolean', 2)
    end

    local prefix = '%?*=*%-?%s*/*'
    local suffix = '%s*%-?'
    local tag_prefix = '{{' .. prefix
    local tag_suffix = suffix .. '}}'
    local len = #txt
    local tags = {}
    local open_tags = {}
    local inloop = 0
    local pos = 1

    if curly == false then
        tag_prefix = '<%?' .. prefix
        tag_suffix = suffix .. '%?>'
    end

    local head, op_head = find(txt, tag_prefix, 1)
    while head do
        local lineno, linecol = linenocol(txt, head)
        local tail, err, tag

        if sub(txt, head + 2, head + 2) == '?' then
            local no_escape = sub(txt, head + 3, head + 3) == '='

            local trim_left
            if no_escape then
                trim_left = sub(txt, head + 4, head + 4) == '-'
            else
                trim_left = sub(txt, head + 3, head + 3) == '-'
            end

            -- skip SP / '-' / '=' / '?'
            if sub(txt, op_head, op_head) ~= '/' then
                op_head = op_head + 1
            end

            tail, err, tag = parse_put_op(tag_suffix, {
                trim_left = trim_left,
                no_escape = no_escape,
                head = head,
                lineno = lineno,
                linecol = linecol,
            }, txt, op_head)
        else
            local trim_left = sub(txt, head + 2, head + 2) == '-'
            tail, err, tag = parse_op(tag_suffix, {
                trim_left = trim_left,
                head = head,
                lineno = lineno,
                linecol = linecol,
                end_op = sub(txt, op_head, op_head) == '/' or nil,
            }, txt, op_head + 1)
        end

        if err then
            return nil, err
        elseif tag then
            if pos < head then
                local ptag = tags[#tags]
                local thead = pos
                local ttail = head - 1

                -- remove newline at head
                if ptag and ptag.trim_right and sub(txt, thead, thead) == '\n' then
                    thead = thead + 1
                end
                -- remove newline at tail
                if tag.trim_left and sub(txt, ttail, ttail) == '\n' then
                    ttail = ttail - 1
                end

                local expr = gsub(sub(txt, thead, ttail), '[\n\'\\]',
                                  ESCAPE_TEXT_EXPR)
                local txtlineno, txtlinecol = linenocol(txt, thead)
                tags[#tags + 1] = {
                    head = thead,
                    tail = ttail,
                    lineno = txtlineno,
                    linecol = txtlinecol,
                    op = 'text',
                    expr = "'" .. expr .. "'",
                }
            end
            pos = tail

            if tag.end_op then
                local otag = open_tags[#open_tags] and open_tags[#open_tags].tag
                if not otag then
                    return nil,
                           format(
                               'invalid tag at %d:%d: closing tag %q is not expected',
                               tag.lineno, tag.linecol, tag.op)
                elseif otag.close_op ~= tag.op then
                    return nil,
                           format(
                               'invalid tag at %d:%d: closing tag %q expected, got %q',
                               tag.lineno, tag.linecol, otag.close_op, tag.op)
                end

                if otag.op == 'for' or otag.op == 'while' then
                    inloop = inloop - 1
                end
                open_tags[#open_tags] = nil
            elseif tag.close_op then
                -- tag must be paired with a closing tag
                open_tags[#open_tags + 1] = {
                    tag = tag,
                    allow_else = tag.op == 'if' or nil,
                }
                if tag.op == 'for' or tag.op == 'while' then
                    inloop = inloop + 1
                end
            elseif tag.op == 'break' then
                if inloop < 1 then
                    return nil,
                           format(
                               'invalid tag at %d:%d: %q tag must be declared inside of %q or %q tag',
                               tag.lineno, tag.linecol, tag.op, 'for', 'while')
                end
            elseif tag.op == 'elseif' or tag.op == 'else' then
                local otag = open_tags[#open_tags]
                if not otag or not otag.allow_else then
                    return nil,
                           format(
                               'invalid tag at %d:%d: %q tag must be declared after %q tag',
                               tag.lineno, tag.linecol, tag.op, 'if')
                end

                -- disable 'elseif' and 'else' ops after 'else' op
                if tag.op == 'else' then
                    otag.allow_else = nil
                end
            end

            tags[#tags + 1] = tag
        end

        head, op_head = find(txt, tag_prefix, tail)
    end

    -- paired opcode is not closed
    if open_tags[#open_tags] then
        local otag = open_tags[#open_tags].tag
        return nil,
               format('invalid tag at %d:%d: %q is not closed by %q tag',
                      otag.lineno, otag.linecol, otag.op, otag.close_op)
    end

    -- extract remaining text
    if pos < len then
        local ptag = tags[#tags]

        -- remove newline at head
        if ptag and ptag.trim_right and sub(txt, pos, pos) == '\n' then
            pos = pos + 1
        end

        local expr = gsub(sub(txt, pos), '[\n\'\\]', ESCAPE_TEXT_EXPR)
        local txtlineno, txtlinecol = linenocol(txt, pos)
        tags[#tags + 1] = {
            head = pos,
            tail = len,
            lineno = txtlineno,
            linecol = txtlinecol,
            op = 'text',
            expr = "'" .. expr .. "'",
        }
    end

    return tags
end

return parse
