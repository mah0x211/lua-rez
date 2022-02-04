require('luacov')
local testcase = require('testcase')
local rez = require('rez')
local escape_html = require('rez.escape').html

function testcase.new()
    -- test that create new rez object
    assert(rez.new())

    -- test that throw an error when invalid arguments are passed
    local err = assert.throws(rez.new, 'foo')
    assert.match(err, 'opts must be table')

    err = assert.throws(rez.new, {
        env = 'foo',
    })
    assert.match(err, 'opts.env must be table')
end

function testcase.add()
    local r = rez.new()

    -- test that add a template
    assert(r:add('hello', [[
        hello {{? $.val }} world
        {{ if $.x == 1 }} 1
        {{ elseif $.x == 2 }} 2
        {{ else }} N
        {{ /if }}
        {{ for i = 1, 3 }}
            i = {{? i }}
            {{ break i == 2 }}
        {{ /for }}
        {{ while $.x < 3 }}
            {{ if x == 2 }}
                {{ break }}
                ignore here {{? $.x }}
            {{ /if }}
        {{code $.x = $.x + 1 }}
        {{ /while }}
    ]]))

    -- test that closing tag x is not expected error
    local ok, err = r:add('parse', [[{{ /if }}]])
    assert.is_false(ok)
    assert.match(err, 'closing tag .+ is not expected', false)

    -- test that closing tag x is expected, got y error
    ok, err = r:add('parse', [[{{ if }}{{ /for }}]])
    assert.is_false(ok)
    assert.match(err, 'closing tag .+ expected, got .+', false)

    -- test that tag must be declared inside of x error
    ok, err = r:add('parse', [[{{ break }}]])
    assert.is_false(ok)
    assert.match(err, 'tag must be declared inside of')

    -- test that tag must be declared after x error
    ok, err = r:add('parse', [[{{ else }}]])
    assert.is_false(ok)
    assert.match(err, 'tag must be declared after')

    -- test that closing tag not declared error
    ok, err = r:add('parse', [[{{ if true }}]])
    assert.is_false(ok)
    assert.match(err, 'not closed by')

    -- test that opcode not declared error
    ok, err = r:add('parse-op', [[{{ ]])
    assert.is_false(ok)
    assert.match(err, 'opcode not declared')

    -- test that unknown opcode error
    ok, err = r:add('parse-op', [[{{ bar }}]])
    assert.is_false(ok)
    assert.match(err, 'unknown opcode')

    -- test that opcode does not support a closing tag error
    ok, err = r:add('parse-op', [[{{ /code }}]])
    assert.is_false(ok)
    assert.match(err, 'opcode .+ does not support a closing tag', false)

    -- test that tag not closed error
    ok, err = r:add('parse-expr', [[{{? bar]])
    assert.is_false(ok)
    assert.match(err, 'not closed by')

    -- test that opcode cannot be declared with an expression error
    ok, err = r:add('parse-expr', [[{{ else foo }}]])
    assert.is_false(ok)
    assert.match(err, 'opcode .+ cannot be declared with an expression', false)

    -- test that contains disallowed keywords error
    ok, err = r:add('tokenize', [[{{ code do }}]])
    assert.is_false(ok)
    assert.match(err, 'contains disallowed keywords')

    -- test that literal token is not closed error
    ok, err = r:add('tokenize', [[{{? "code }}]])
    assert.is_false(ok)
    assert.match(err, 'literal token is not closed')

    -- test that syntax error
    ok, err = r:add('compile', [[
        hello
        {{? foo bar;  }}
        world]])
    assert.is_false(ok)
    assert.match(err, 'compile"%]:2.+', false)

    -- test that throws an error when invalid arguments are passed
    err = assert.throws(r.add, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.add, r, 'foo', 123)
    assert.match(err, 'str must be string')
end

function testcase.del()
    local r = rez.new()
    assert(r:add('hello', [[world]]))

    -- test that delete a template
    assert(r:del('hello'))
    assert.is_false(r:del('hello'))

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.render, r, 123)
    assert.match(err, 'name must be string')
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
{{? rez.render('header') }}
{{? $.main }}
{{? rez.render('footer') -}}
]]))
    assert(r:add('nav', [[
global-nav
{{? $.subnav }}]]))
    assert(r:add('subnav', [[
sub-nav
{{- code rez.layout('nav', 'subnav') -}}]]))
    assert(r:add('main', [[
{{? rez.render('subnav') }}
main-contents: {{? $.hello }} {{? world() }}
{{- code rez.layout('layout', 'main') }}]]))
    local res = assert(r:render('main', {
        hello = 'hello',
    }))
    assert.equal(res, [[
header
global-nav
sub-nav
main-contents: hello world!
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
<?? rez.render('header') ?>
<?? $.main ?>
<?? rez.render('footer') -?>
]]))
    assert(r:add('nav', [[
global-nav
<?? $.subnav ?>]]))
    assert(r:add('subnav', [[
sub-nav
<?- code rez.layout('nav', 'subnav') -?>]]))
    assert(r:add('main', [[
<?? rez.render('subnav') ?>
main-contents: <?? $.hello ?> <?? world() ?>
<?- code rez.layout('layout', 'main') ?>]]))
    local res = assert(r:render('main', {
        hello = 'hello',
    }))
    assert.equal(res, [[
header
global-nav
sub-nav
main-contents: hello world!
footer]])

    -- test that throws an error when invalid arguments are passed
    local err = assert.throws(r.render, r, 123)
    assert.match(err, 'name must be string')

    err = assert.throws(r.render, r, 'foo', 'bar')
    assert.match(err, 'data must be table')
end

function testcase.escape_ouput()
    local r = rez.new({
        escape = escape_html,
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(r:add('escape', [[<p>
{{- ? $.xss }}
{{- ?= $.no_escape }}</p>]]))
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

