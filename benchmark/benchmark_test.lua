local testcase = require('testcase')
local nanotime = require('chronos').nanotime

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

local function benchmark(r, cmp)
    local N = 100000
    local t = nanotime()

    for _ = 1, N do
        _ = r:render('main', {
            hello = 'hello',
        })
        -- local res = r:render('main', {
        --     hello = 'hello',
        -- })
        -- assert.equal(res, cmp)
    end

    return N, (nanotime() - t) * 1000
end

local function setup_layout()
    local rez = require('rez').new({
        escape = require('rez.escape').html,
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(rez:add('header', [[header]]))
    assert(rez:add('footer', [[footer]]))
    assert(rez:add('layout', [[
{{? rez.render('header') }}
{{? $.main }}
{{? rez.render('footer') -}}
]]))
    assert(rez:add('nav', [[
global-nav
{{? $.subnav }}]]))
    assert(rez:add('subnav', [[
sub-nav
{{- code rez.layout('nav', 'subnav') -}}]]))
    assert(rez:add('main', [[
{{? rez.render('subnav') }}
main-contents: {{? $.hello }} {{? world() }}
{{- code rez.layout('layout', 'main') }}]]))
    return rez, [[
header
global-nav
sub-nav
main-contents: hello world!
footer]]

end

local function setup_simple()
    local rez = require('rez').new({
        escape = require('rez.escape').html,
        env = {
            world = function()
                return 'world!'
            end,
        },
    })

    -- test that render template
    assert(rez:add('main', [[
main-contents: {{? $.hello }} {{? world() }}
]]))
    return rez, [[main-contents: hello world!]]
end

function testcase.bench_simple()
    local rez, cmp = setup_simple()
    local N, t = benchmark(rez, cmp)
    printf('time elapsed %f ms for %d ops | %f us/op', t, N, (t / N) * 1000)
end

function testcase.bench_layout()
    local rez, cmp = setup_layout()
    local N, t = benchmark(rez, cmp)
    printf('time elapsed %f ms for %d ops | %f us/op', t, N, (t / N) * 1000)
end
