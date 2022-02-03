local testcase = require('testcase')
local escape = require('rez.escape')

function testcase.html()
    -- test that escape html characters
    assert.equal(escape.html("foo\"'&<" .. string.char(0) .. '>bar'),
                 'foo&#34;&#39;&amp;&lt;' .. string.char(0xef, 0xbf, 0xbd) ..
                     '&gt;bar')
end

