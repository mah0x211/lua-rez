# lua-rez

A simple template engine for lua.


## r = rez.new( [opts] )

create new rez object.

**Parameters**

- `opts:table`
  - `env:table<string, any>`: template environment. (default `nil`)
  
**Returns**

- `r:rez`: template object.


**Example**

```lua
local rez = require('rez').new({
    -- export the functions to template environment
    env = {
        hello = function()
            return 'world'
        end,
    },
})
```


## ok, err = r:add( name, str )

add the template `str` and set the name `name`.

**Parameters**

- `name:string`: name of the template.
- `str:string`: template string.

**Returns**

- `ok:boolean`: `true` on success.
- `err:string`: error message.

**Example**

```lua
local rez = require('rez').new()
assert(rez:add('/index.html', '<?? "hello world" ?>' ))
```

## ok = r:del( name )

deletes the template with the specified `name`.

**Parameters**

- `name:string`: name of the template.

**Returns**

- `ok:boolean`: `true` on success, or `false` if not found.

**Example**

```lua
local rez = require('rez').new()
assert(rez:add('/index.html', '<?? "hello world" ?>'))
assert(rez:del('/index.html'))
```

## res, err = rez:render( name [, data] )

renders the template specified by `name`.

**Parameters**

- `name:string`: name of the template.
- `data:table`: data that can be accessed with `$` in the template. (default: `{}`)

**Returns**

- `res:string`: rendered string on success, or `nil` on failure.
- `err:string`: error message.

**Example**

```lua
local rez = require('rez').new()
assert(rez:add('/index.html', [[
<?? $.hello ?> <?? $.world ?>
]]))
local res = assert(rez:render('/index.html', {
    hello = 'Hello',
    world = 'World!',
}))
print(res)
```


# Template Syntax

the input text for a template is text in any format. `Statements` --data evaluations or control structures-- are delimited by `<?` and `?>`; all text outside statements is copied to the output unchanged. also, if specified with a hyphen (`<?-`, `-?>`), the preceding and following a newline character `\n` will be deleted.


## Output Statement

output the result of the expression `expr`.

**Syntax**

```
<?? [expr] ?>
```


**Example**

```
<?? 'Hello World' ?>
<?? 1 + 10 ?>
<?? 'Hello', 'World' ?>
```

the above template will be rendered as follows.

```
Hello World
11
Hello
```


## Write Lua Code

you can write Lua code other than control statements.

**Syntax**

```
<? code [expr] ?>
```

**Example**

```
<?code local x = 1 ?>
<?code local y = { 1, 2, 3 } ?>
<?code local z = table.concat( y, '-' ) ?>
<?code local a = 1; x = z ?>
```

**NOTE:** you cannot declare a global variable.

```
<?code hello = 'world' ?>
```

the above template will be error occurred as follows.

```
attempt to change global environment
```


## Conditional Statement

A conditional statement starts with `<? if expr ?>` and ends with `<? /if ?>`.
A conditional statement starts with `<? if expr ?>`, adds branches with `<? elseif expr ?>` or `<? else ?>` as needed, and ends with `<? /if ?>`.

**Syntax**

```
<?if expr ?> 
... 
<?elseif expr ?>
.. 
<?else?> 
...
<?/if?>
```


**Exampl**

```
<? code local x = 3 >
<? if x == 1 ?>
x is 1
<? elseif x == 2 ?>
x is 2
<? else ?>
x is <?? x ?>
<? /if ?>
```

the above template will be rendered as follows.

```
x is 3
```


## Iteration statements

`<? for expr ?>`, `<? while expr ?>` and `<? break [expr] ?>` statements are can be used for the iteration statement.

**Syntax**

```
<? for expr ?>
...
<? break [expr] ?>
...
<? /for ?>
```

```
<? while expr ?>
...
<? break [expr] ?>
...
<? /while ?>
```


**Example**

```
<? for i = 1, 20, 2 ?>
<? break i >= 10 ?>
i = <?? i ?>
<? /for ?>
```

```
<?code local i = 1 ?>
<? while i <= 20 ?>
i = <?? i ?>
<?code i = i + 2 ?>
<? break i >= 10 ?>
<? /while ?>
```

```
<?code local i = 1 ?>
<? while i <= 20 ?>
i = <?? i ?>
<?code i = i + 2 ?>
<? if i >= 10 ?><? break ?><? /if ?>
<? /while ?>
```

the above templates will be rendered as follows.

```
i = 1
i = 3
i = 5
i = 7
i = 9
```


## Functions available in the template

Please see [lib/newfenv.lua](lib/newfenv.lua) for available functions.

In addition, the following built-in functions can be used to render in combination with another template.

## str = rez.render( name )

renders the template specified by `name`. also, external data will be passed over automatically.

**Parameters**

- `name:string`: name of the template.

**Returns**

- `res:string`: rendered string on success, or `nil` on failure.
- `err:string`: error message.

**Example**

```
<?? rez.render('other_template_name') ?>
```

## rez.layout( name, varname )

After rendering is finished, the result is stored in the field specified by `varname` in the `data` table, and then the template specified by `name` is ordered to be rendered.

**Parameters**

- `name:string`: name of the template.
- `varname:string`: variable name.


**Example**

```lua
local rez = require('rez').new()

-- add layout template
rez:add('my-layout', [[
Hello My Layout
<?? $.contents ?>
]])

-- add main-contents template
rez:add('main-contents', [[
this is main contents
<?code rez.layout('my-layout', 'contents') ?>
]])

-- render main-contents
local res = rez:render('main-contents')
print(res)
```

the above code will be rendered as follows.

```
Hello My Layout
this is main contents
```

the following code is equivalent to the above code.


```lua
local rez = require('rez').new()

-- add layout template
rez:add('my-layout', [[
Hello My Layout
<?? $.contents ?>
]])

-- add main-contents template
rez:add('main-contents', [[
this is main contents
]])

-- render my-layout
local res = rez:render('my-layout', {
    -- render main-contents
    contents = rez:render('main-contents')
})
print(res)
```

