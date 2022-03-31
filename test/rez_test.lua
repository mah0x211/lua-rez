require('luacov')
local testcase = require('testcase')
local rez = require('rez')

function testcase.new()
    -- test that create new rez object
    assert(rez.new())

    -- test that throw an error when invalid arguments are passed
    local err = assert.throws(rez.new, 'foo')
    assert.match(err, 'opts must be table')

    err = assert.throws(rez.new, {
        curly = 'foo',
    })
    assert.match(err, 'opts.curly must be boolean')

    err = assert.throws(rez.new, {
        escape = 'foo',
    })
    assert.match(err, 'opts.escape must be callable')

    err = assert.throws(rez.new, {
        loader = {},
    })
    assert.match(err, 'opts.loader must be callable')

    err = assert.throws(rez.new, {
        env = 'foo',
    })
    assert.match(err, 'opts.env must be table')
end

function testcase.add_exists()
    local r = rez.new()

    -- test that add a template
    assert(r:add('hello', [[
        hello {{ $.val}} world
        {{if $.x == 1}} 1
        {{elseif $.x == 2}} 2
        {{else}} N
        {{/if}}
        {{for i = 1, 3}}
            i = {{i}}
            {{break i == 2}}
        {{/for}}
        {{while $.x < 3}}
            {{if x == 2}}
                {{break}}
                ignore here {{ $.x }}
            {{/if}}
        {{code $.x = $.x + 1}}
        {{/while}}
    ]]))
    assert.is_true(r:exists('hello'))

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.add, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.add, r, 'foo', 123)
    assert.match(err, 'str must be string')

    -- test that throws an error when invalid arguments are passed
    err = assert.throws(r.exists, r, 123)
    assert.match(err, 'name must be string')
end

function testcase.del()
    local r = rez.new()
    assert(r:add('hello', [[world]]))

    -- test that delete a template
    assert(r:del('hello'))
    assert.is_false(r:del('hello'))

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.del, r, 123)
    assert.match(err, 'name must be string')
end

function testcase.clear()
    local r = rez.new()
    assert(r:add('hello', [[world]]))
    assert(r:add('foo', [[bar]]))

    -- test that delete a template
    r:clear()
    assert.is_false(r:del('hello'))
    assert.is_false(r:del('foo'))
end

function testcase.render()
    local r = rez.new({
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(r:add('header', [[header]]))
    assert(r:add('footer', [[footer]]))
    assert(r:add('layout', [[
{{ rez.render('header') }}
{{ $.main }} {{? local foo = 'foo' }}{{ foo }}
{{ rez.render('footer') -}}
]]))
    assert(r:add('nav', [[
global-nav
{{ $.subnav }}]]))
    assert(r:add('subnav', [[
sub-nav
{{- code rez.layout('nav', 'subnav') -}}]]))
    assert(r:add('main', [[
{{ rez.render('subnav') }}
main-contents: {{ $.hello }} {{ world() }}
{{- code rez.layout('layout', 'main') }}]]))
    local res = assert(r:render('main', {
        hello = 'hello',
    }))
    assert.equal(res, [[
header
global-nav
sub-nav
main-contents: hello world! foo
footer]])

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.render, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.render, r, 'foo', 'bar')
    assert.match(err, 'data must be table')
end

function testcase.render_no_curly()
    local r = rez.new({
        curly = false,
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(r:add('header', [[header]]))
    assert(r:add('footer', [[footer]]))
    assert(r:add('layout', [[
<? rez.render('header') ?>
<? $.main ?> <? ? local foo = 'foo' ?><? foo ?>
<? rez.render('footer') -?>
]]))
    assert(r:add('nav', [[
global-nav
<? $.subnav ?>]]))
    assert(r:add('subnav', [[
sub-nav
<?- code rez.layout('nav', 'subnav') -?>]]))
    assert(r:add('main', [[
<? rez.render('subnav') ?>
main-contents: <? $.hello ?> <? world() ?>
<?- code rez.layout('layout', 'main') ?>]]))
    local res = assert(r:render('main', {
        hello = 'hello',
    }))
    assert.equal(res, [[
header
global-nav
sub-nav
main-contents: hello world! foo
footer]])

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.render, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.render, r, 'foo', 'bar')
    assert.match(err, 'data must be table')
end

function testcase.escape_ouput()
    local r = rez.new({
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(r:add('escape', [[<p>
{{- $.xss }}
{{- = $.no_escape }}</p>]]))
    local res = assert(r:render('escape', {
        xss = '<script> alert("xss"); </script>',
        no_escape = '<hello>',
    }))
    assert.equal(res,
                 [[<p>&lt;script&gt; alert(&#34;xss&#34;); &lt;/script&gt;<hello></p>]])

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.render, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.render, r, 'foo', 'bar')
    assert.match(err, 'data must be table')
end

function testcase.render_with_loader()
    local r = rez.new({
        loader = setmetatable({}, {
            __call = function(_, r, name)
                if name == 'header' then
                    return r:add('header', [[header]])
                elseif name == 'footer' then
                    return r:add('footer', [[footer]])
                elseif name == 'layout' then
                    return r:add('layout', [[
{{ rez.render('header') }}
{{ $.main }}
{{ rez.render('footer') -}}
]])
                elseif name == 'nav' then
                    return r:add('nav', [[
global-nav
{{ $.subnav }}]])
                elseif name == 'subnav' then
                    return r:add('subnav', [[
sub-nav
{{- code rez.layout('nav', 'subnav') -}}]])
                elseif name == 'main' then
                    return r:add('main', [[
{{ rez.render('subnav') }}
main-contents: {{ $.hello }} {{ world() }}
{{- code rez.layout('layout', 'main') }}]])
                else
                    return false, 'not found'
                end
            end,
        }),
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    local res = assert(r:render('main', {
        hello = 'hello',
    }))
    assert.equal(res, [[
header
global-nav
sub-nav
main-contents: hello world!
footer]])

    -- test that return an error
    r:clear()
    r.loader = function()
        return false, 'failed to load template'
    end
    local err
    res, err = r:render('foo')
    assert.is_nil(res)
    assert.match(err, 'failed to load template')
end

function testcase.builtin_rez_escape()
    local r = rez.new({
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(r:add('escape', [[<p>
{{- rez.escape_html($.xss) }}
{{- = rez.escape_html($.no_escape) }}</p>]]))
    local res = assert(r:render('escape', {
        xss = '<script> alert("xss"); </script>',
        no_escape = '<hello>',
    }))
    assert.equal(res,
                 [[<p>&amp;lt;script&amp;gt; alert(&amp;#34;xss&amp;#34;); &amp;lt;/script&amp;gt;&lt;hello&gt;</p>]])
end

function testcase.syntax_if_elseif_else()
    local r = rez.new()

    -- test that render template
    assert(r:add('parse',
                 [[{{if true }}hello{{elseif true }}rez{{else}}world{{/if}}]]))
    local res = assert(r:render('parse'))
    assert.equal(res, 'hello')

    -- test that return an error
    local ok, err = r:add('parse', [[
        {{ if }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "if" must be declared with an expression')

    ok, err = r:add('parse', [[
        {{ if true }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"if" is not closed by "/if" tag')

    ok, err = r:add('parse', [[
        {{ if true }}
        {{ elseif true }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"if" is not closed by "/if" tag')

    ok, err = r:add('parse', [[
        {{ if true }}
        {{ elseif true }}
        {{ else }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"if" is not closed by "/if" tag')

    ok, err = r:add('parse', [[
        {{ /if }}}
    ]])
    assert.is_false(ok)
    assert.match(err, 'closing tag "/if" is not expected')

    ok, err = r:add('parse', [[
        {{ /if 1 + 1 }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "/if" cannot be declared with an expression')

    ok, err = r:add('parse', [[
        {{ elseif }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "elseif" must be declared with an expression')

    ok, err = r:add('parse', [[
        {{ elseif true }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"elseif" tag must be declared after "if" tag')

    ok, err = r:add('parse', [[
        {{ /elseif true }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "elseif" does not support a closing tag')

    ok, err = r:add('parse', [[
        {{ else true }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "else" cannot be declared with an expression')

    ok, err = r:add('parse', [[
        {{ else }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"else" tag must be declared after "if" tag')

    ok, err = r:add('parse', [[
        {{ /else }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "else" does not support a closing tag')
end

function testcase.syntax_for()
    local r = rez.new()

    -- test that render template
    assert(r:add('parse', [[{{for i = 1, 3 }}hello{{/for}}]]))
    local res = assert(r:render('parse'))
    assert.equal(res, 'hellohellohello')

    -- test that return an error
    local ok, err = r:add('parse', [[
        {{ for }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "for" must be declared with an expression')

    ok, err = r:add('parse', [[
        {{ for true }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"for" is not closed by "/for" tag')

    ok, err = r:add('parse', [[
        {{ /for 1 + 1 }}}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "/for" cannot be declared with an expression')

    ok, err = r:add('parse', [[
        {{ /for }}}
    ]])
    assert.is_false(ok)
    assert.match(err, 'closing tag "/for" is not expected')
end

function testcase.syntax_while()
    local r = rez.new()

    -- test that render template
    assert(r:add('parse',
                 [[{{while $.i < 3 }}hello{{? $.i = $.i + 1}}{{/while}}]]))
    local res = assert(r:render('parse', {
        i = 0,
    }))
    assert.equal(res, 'hellohellohello')

    -- test that return an error
    local ok, err = r:add('parse', [[
        {{ while }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "while" must be declared with an expression')

    ok, err = r:add('parse', [[
        {{ while true }}
    ]])
    assert.is_false(ok)
    assert.match(err, '"while" is not closed by "/while" tag')

    ok, err = r:add('parse', [[
        {{ /while 1 + 1 }}}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "/while" cannot be declared with an expression')

    ok, err = r:add('parse', [[
        {{ /while }}}
    ]])
    assert.is_false(ok)
    assert.match(err, 'closing tag "/while" is not expected')
end

function testcase.syntax_break()
    local r = rez.new()

    -- test that render template
    assert(r:add('parse', [[{{for i = 0, 3 }}hello{{break}}{{/for}}]]))
    local res = assert(r:render('parse'))
    assert.equal(res, 'hello')

    assert(r:add('parse', [[{{for i = 0, 3 }}{{break i == 2 }}hello{{/for}}]]))
    res = assert(r:render('parse'))
    assert.equal(res, 'hellohello')

    assert(r:add('parse',
                 [[{{while $.i < 3 }}hello{{? $.i = $.i + 1}}{{break}}{{/while}}]]))
    res = assert(r:render('parse', {
        i = 0,
    }))
    assert.equal(res, 'hello')

    assert(r:add('parse',
                 [[{{while $.i < 3 }}{{break $.i == 2 }}hello{{? $.i = $.i + 1}}{{/while}}]]))
    res = assert(r:render('parse', {
        i = 0,
    }))
    assert.equal(res, 'hellohello')

    -- test that return an error
    local ok, err = r:add('parse', [[
        {{ break }}
    ]])
    assert.is_false(ok)
    assert.match(err,
                 '"break" tag must be declared inside of "for" or "while" tag')

    ok, err = r:add('parse', [[{{ /break }}]])
    assert.is_false(ok)
    assert.match(err, 'opcode "break" does not support a closing tag')
end

function testcase.syntax_code()
    local r = rez.new()

    -- test that render template
    assert(r:add('parse', [[{{code $.i = $.i + 1 }}]]))
    local data = {
        i = 0,
    }
    local res = assert(r:render('parse', data))
    assert.equal(res, '')
    assert.equal(data, {
        i = 1,
    })

    assert(r:add('parse', [[{{? $.i = $.i + 1 }}]]))
    res = assert(r:render('parse', data))
    assert.equal(res, '')
    assert.equal(data, {
        i = 2,
    })

    -- test that return an error
    local ok, err = r:add('parse', [[
        {{ code }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "code" must be declared with an expression')

    ok, err = r:add('parse', [[
        {{ /code }}
    ]])
    assert.is_false(ok)
    assert.match(err, 'opcode "code" does not support a closing tag')
end

function testcase.syntax_tag_declaration()
    local r = rez.new()

    -- test that opcode not declared error
    local ok, err = r:add('parse-op', [[{{ ]])
    assert.is_false(ok)
    assert.match(err, 'opcode not declared')

    -- test that tag not closed error
    ok, err = r:add('parse-expr', [[{{ foo]])
    assert.is_false(ok)
    assert.match(err, 'not closed by "}}"')
end

function testcase.syntax_tokenize()
    local format = string.format
    local r = rez.new()

    -- test that contains disallowed keywords error
    for _, keyword in ipairs({
        'self',
        'break',
        'do',
        'else',
        'elseif',
        'end',
        'for',
        'function',
        'goto',
        'nil',
        'repeat',
        'return',
        'then',
        'until',
        'while',
    }) do
        local ok, err = r:add('tokenize', format([[
            {{? %s }}
        ]], keyword))
        assert.is_false(ok)
        assert.match(err, format('contains disallowed keywords %q', keyword))
    end

    -- test that literal token is not closed error
    for sym_open, sym_close in pairs({
        ["'"] = "'",
        ['"'] = '"',
        ['[['] = ']]',
        ['[=['] = ']=]',
        ['[==['] = ']==]',
    }) do
        local ok, err = r:add('tokenize', format([[
            {{ %sliteral }}
        ]], sym_open))
        assert.is_false(ok)
        assert.match(err, format('literal token is not closed by %q', sym_close))
    end

    -- test that bracket token is not closed error
    for sym_open, sym_close in pairs({
        ['['] = ']',
        ['{'] = '}',
        ['('] = ')',
    }) do
        local ok, err = r:add('tokenize', format([[
        {{ %s  }}
    ]], sym_open))
        assert.is_false(ok)
        assert.match(err, format('bracket token %q is not closed by %q',
                                 sym_open, sym_close))
    end

    -- test that illegal bracket token error
    for _, sym_close in ipairs({
        ']',
        '}',
        ')',
    }) do
        local ok, err = r:add('tokenize', format([[
        {{ %s  }}
    ]], sym_close))
        assert.is_false(ok)
        assert.match(err, format('illegal bracket token %q', sym_close))
    end
end
