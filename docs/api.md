Aspect for Developers
=====================

This chapter describes the API to Aspect and not the template language. 
It will be most useful as reference to those implementing the template interface to the application 
and not those who are creating Aspect templates.

Basic API Usage
--------------

Get Aspect from `aspect.template` package
```lua
local aspect = require("aspect.template").new(options)
```

`options` variable store Aspect configuration. 

Aspect uses a loader `aspect.loader` to locate templates

```lua
aspect.loader = function (name)
    local templates = {
        index = 'Hello {{ name }}!',
    }
    return templates[name]
end
```

The `display()` method loads the template passed as a first argument and renders it with the variables passed as a second argument.

```lua
aspect:display("dashboard.tpl", {
    title = "hello world",
    data = app:get_data()
})
```

Rendering Templates
-------------------

* To render the template with some variables, call the `render()` method:
  ```lua
  print(aspect:render('index.html', {the = 'variables', go = 'here'}))
  ```
* If a template defines blocks, they can be rendered individually via the `render_block()`:
  ```lua
  print(aspect:render_block('index.html', 'block_name', {the = 'variables', go = 'here'})) 
  ```
* If a template defines macros, they can be rendered individually via the `render_macro()`:
  ```lua
  print(aspect:render_macro('index.html', 'macro_name', {the = 'variables', go = 'here'})) 
  ```
* The `display()`, `display_block()`, `display_macro()` methods are shortcuts to output the rendered template.
  
  ```lua
  aspect:display('index.html', {the = 'variables', go = 'here'})
  aspect:display_block('index.html', 'block_name', {the = 'variables', go = 'here'})
  aspect:display_macro('index.html', 'macro_name', {the = 'variables', go = 'here'})
  ```
  Also method has some options for output:
  ```lua 
  aspect:display('index.html', vars, {chunk_size = 8198, print = ngx.print})
  ```
  Possible options are:
  * `chunk_size` (number) - buffer size before sending data to `print`. By default - `nil`, buffer disabled.
  * `print` (callable) - callback used to send data. By default - `ngx.print or print`.

**Note**. `render` functions and `display` functions returns `aspect.output` object with template result 
(if result not displayed) and more useful information

Options
-------

When creating a new `aspect.template` instance, you can pass an table of options as the constructor argument:
```lua
local aspect = require("aspect.template").new({
    cache = true, 
    debug = true
})
```
The following options are available:
* `debug` _boolean_.
  When set to true, templates generates notices in some obscure situations. Also enables `dump` function.
* `cache` _table_ or `false` or `true`
  Enables or disables in-memory cache. If this parameter is a table, then it will be used to store the cache. 
  If `true` - own table will be used.
* `loader` _function_ `fun(name: string):string,string`.
  Template source code loader with etag (optionally)
* `luacode_load` _function_ `fun(tpl: aspect.template, name: string):string`
  Function used for loading compiled lua code of the template.
* `luacode_save` _function_ `fun(tpl: aspect.template, name: string, luacode: string)`
  Function used for saving compiled lua code of the template.
* `bytecode_load` _function_ `fun(tpl: aspect.template, name: string):string`
  Function used for loading byte-code of the template.
* `bytecode_save` _function_ `fun(tpl: aspect.template, name: string, bytecode: string)`
  Function used for saving byte-code of the template.
* `autoescape` _boolean_
  Enables or disables auto-escaping with 'html' strategy. 

Cache
-----

Aspect template has 3 level of cache:

1. lua code cache — normal (Aspect's functions `luacode_load` and `luacode_save`).
2. byte code cache — fast (Aspect's functions `bytecode_load` and `bytecode_save`).
3. `aspect.view` object cache (internal) — fastest (Aspect's property `cache`)

Cache stages:

0. _Require the template_
1. Get `aspect.view` from internal (table in the `aspect.template`) cache.
2. Get bytcode using `bytecode_load` function.
3. Get lua code using `luacode_load` function.
4. _Get template source code using `loader` function. Compile it._
5. Save lua code using `luacode_save` function.
6. Save bytcode using `bytecode_save` function.
7. Save `aspect.view` into internal (table in the `aspect.template`) cache.
8. _Render the template_

```lua
local aspect = require("aspect.template")

local template = aspect.new({
    cache = true -- enable internal lua in-memory cache 
})
template.bytecode_load = function (t, name)
    -- load bytecode from nginx shared dictionary
    return ngx.shared["cache"]:get(name)
end
template.luacode_load = function (t, name)
    -- load lua code from redis
    return redis:get(name)
end
template.luacode_save = function (t, name, luacode)
    -- save lua code into redis
    redis:set(name, luacode)
end
template.bytecode_save = function (t, name, bytecode)
    -- save bytecode into nginx shared dictionary
    ngx.shared["cache"]:set(name, bytecode)
end
```

Use custom table for internal cache:

```lua
local aspect = require("aspect.template")
local template = aspect.new({
    cache = app.views -- use own app.views table for storing aspect.view objects
})
```

Loaders
-------

Loader should be callback or callable object.

### File system loader

```lua
aspect.loader = require("aspect.loader.filesystem").new(project_root .. "/templates")
```

### Resty loader

### Array loader

```lua
local tpls = require("aspect.loader.array").new()

tpls["dashboard.tpl"] = [[ ... template ... ]]
tpls["theme.tpl"] = [[<html> ... template ... </html>]]

aspect.loader = tpls
```

Add tags
--------

Add inline tag `{% foo %}`:

```lua
local tags = require("aspect.tags")

--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string|table of lua code
function tags.foo(compiler, tok)
    -- ...
end
```

Add block tag `{% bar %} ... {% endbar %}`:

```lua
local tags = require("aspect.tags")

--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string|table of lua code
function tags.bar(compiler, tok)
    -- ...
    local tag = compiler:push_tag('bar')
    --- tag.buz = ...
    -- ...
end

--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string|table of lua code
function tags.endbar(compiler, tok)
    -- ...
    local tag = compiler:pop_tag('bar')
    -- ...
end
```

See [aspect.tags](../src/aspect/tags.lua) for more examples.

Add filters
-----------

```lua
local filters = require("aspect.filters")

filters.add("foo", {"arg1", "arg2"}, function (v, arg1, arg2) 

end)
```

See [aspect.filters](../src/aspect/filters.lua) for more examples.

Add functions
-------------

Add function `{{ foo(arg1=x, arg2=y) }}`:

```lua
local funcs = require("aspect.funcs")

--- Define foo's arguments
funcs.args.foo = {"arg1", "arg2"}

--- Optional. The function will be called when the template is compiled.
--- @param compiler aspect.compiler
--- @param args table
--- @return string the lua code
function funcs.parsers.foo(compiler, args)
    -- ...
end

--- The function will be called when the template is executed.
--- @param __ aspect.output
--- @param args table arguments witch listed in the funcs.args.foo
--- @return string the output
function funcs.fs.foo(__, args)
    -- ...
 end 
```

See [aspect.funcs](../src/aspect/funcs.lua) for more examples.

Add tests
---------

Add tests `foo`, `bar` and `baz`

```lua
local tests = require("aspect.tests")

tests.add('foo', function (__, v)
    -- return boolean
end)

tests.add('bar', function (__, v, arg)
    -- return boolean
end, true)

tests.add('baz', function (__, v, arg)
    -- return boolean
end, "quux")
```

Result:

```twig
{{ a is foo }}
{{ a is bar(c) }}
{{ a is baz quux(c) }}
```

See [aspect.tests](../src/aspect/tests.lua) for more examples.

Add operators
-------------

For example add bitwise operator `&` (using [bitop](http://bitop.luajit.org/) package): 

```lua
local ops = require("aspect.ast.ops")

-- Push new operator to the operators array

--- Define 'and' bitwise operator.
--- @see aspect.ast.op
table.insert(ops, {
    token = "&", -- one-symbol-token for parser 
    order = 7, -- operator precedence (1 - high priority, 14 - low priority)
    l = "number", -- left operand should be number
    r = "number", -- right operand should be number
    out = "number", -- result of the operator is number
    type = "binary", -- operator with two operands
    pack = function (left, right) -- build lua code
        return "bit.band(" .. left .. ", " .. right .. ")"
    end
})
```

See [aspect.ast.ops](../src/aspect/ast/ops.lua) for more examples.

Behaviors
---------

### Condition behaviour

Cast specific tables and userdata to false. 

For persistent tables and userdata:

```lua
local cjson = require("cjson.safe")
local is_false = require("aspect.config").is_false

--- cjson.null the same thing every time
is_false[cjson.null] = true -- use userdata as key
```

For runtime tables and userdata use their metatable:

```lua
local cbson = require("cbson")
local is_false = require("aspect.config").is_false

--- cbson.null() creates every time new 'null' userdata object
--- metatable will be used for comparison 
is_false[getmetatable(cbson.null())] = true
```

Add zero-string behaviour.

```twig
{% set zero = "0" %} {# zero as string #}

{% if zero %}
    Unaceptable condition!
{% end %}
```

Example do nothing because `zero` will be casted to `true` (`"0"` not 'empty').

Add behaviour for `0`

```lua
local is_false = require("aspect.config").is_false
is_false['0'] = true
```
 
Now example output `Unaceptable condition!` because `zero` will be casted to false.

Custom escaper
--------------

Add custom escaper via config, using escaper name: 

```lua
require("aspect.config").escapers.csv = function(value) 
    -- ... 
end
```

```twig
{{ data.raw|e("csv") }}
```