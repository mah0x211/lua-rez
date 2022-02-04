std = 'max'
include_files = {
    'rez.lua',
    'lib/*.lua',
    'test/*_test.lua',
    'benchmark/*_test.lua',
}
ignore = {
    'assert',
    -- unused argument
    '212',
}

