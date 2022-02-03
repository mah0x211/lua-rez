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
local match = string.match
local tonumber = tonumber

--- generate error string with source mapping table
--- @return string err
local function errmap(label, tags, err)
    if type(label) ~= 'string' then
        error('label must be string', 2)
    elseif type(err) ~= 'string' then
        error('err must be string', 2)
    elseif tags == nil then
        return err
    elseif type(tags) ~= 'table' then
        error('tags must be table', 2)
    end

    -- find error position
    local idx, msg = match(err, ':(%d+):(.*)');
    if not idx then
        return err
    end

    --
    -- NOTE: should subtract 1 from line-number because code generator will
    -- generate the code as below;
    --
    --  - first-line: function declaration.
    --  - and, logic code...
    --
    idx = tonumber(idx, 10) - 1
    local tag = tags[idx]
    if not tag then
        return err
    end

    return format('invalid tag at [%q]:%d:%d: %s', label, tag.lineno,
                  tag.linecol, msg)
end

return errmap
