---
layout: page
title: API Documentation
---

<!-- {% raw %} -->

This chapter describes the API to Aspect and not the template language. 
It will be most useful as reference to those implementing the template interface to the application 
and not those who are creating Aspect templates.

Basic API Usage
--------------

Get Aspect from `aspect.template` package
```lua
local aspect = require("aspect.template").new(options)
```

[`options`](#options) variable store Aspect configuration. 

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

## Render result

```lua
local output, err = aspect:display(template, vars)
```

- `output` is `aspect.output` object and contains rendering information, even if the rendering failed. 
  If you use `aspect:render` method `output` contains rendered string:
  ```lua
  local output, err = aspect:render(template, vars)
  if not err then
      io.write(tostring(output))
  end
  ```
- `err` is `aspect.error` object and contains error information. `nil` if no errors.

Render Templates
----------------

* To render the template with some variables, call the `render()` method:
  ```lua
  local result, error = aspect:render('index.html', {the = 'variables', go = 'here'})
  ```
* If a template defines blocks, they can be rendered individually via the `render_block()`:
  ```lua
  local result, error = aspect:render_block('index.html', 'block_name', {the = 'variables', go = 'here'})
  ```
* If a template defines macros, they can be rendered individually via the `render_macro()`:
  ```lua
  local result, error = aspect:render_macro('index.html', 'macro_name', {the = 'variables', go = 'here'}) 
  ```
* The `display()`, `display_block()`, `display_macro()` methods are shortcuts to output the rendered template.
  
  ```lua
  aspect:display('index.html', {the = 'variables', go = 'here'})
  aspect:display_block('index.html', 'block_name', {the = 'variables', go = 'here'})
  aspect:display_macro('index.html', 'macro_name', {the = 'variables', go = 'here'})
  ```
  
  Also method has some options for output:
  
  ```lua 
  aspect:render('index.html', vars, {chunk_size = 8198, print = ngx.print})
  ```
  Possible options are:
  * `chunk_size` (number) - buffer size before sending data to `print`. By default - `nil`, buffer disabled.
  * `print` (callable) - callback used to send data. By default - `ngx.print or print`.

**Note**. `render` functions and `display` functions returns `aspect.output` object with template result 
(if result not displayed) and more useful information

Debug Templates
---------------

If compilation errors or template execution fail, you can get an `aspect.error` error object that contains fields:
- **code** — code or type of error
  - `syntax` - template syntax error
  - `compile` - template compilation error not related to syntax (unknown filter, wrong arguments, etc)
  - `compiler` - internal compiler's error
  - `runtime` - error executing template
- **name** — name of the template in which the error was occurred
- **line** — line of the template in which the error was occurred
- **message** — the error message
- **context** — fragment of the template where the error occurred (`runtime` and `compiler` errors have no context)
- **callstack** — trace template calls as a string.
- **traceback** — Lua trace back 

The error object `aspect.error` can be converted to a string with a detailed description of the error.

```lua
local output, error = aspect:render("launch.view")
if error then
    print(tostring(error))
end
```

To get more information (lua code, used variables e.g.) about the template, use the builder object `aspect.compiler`

```lua
local builder, error = aspect:compile("launch.view")
if builder then 
    print("Lua code of the template launch.view:\n", builder:get_code())
else
    print("Error occurred: ", tostring(error))
end
```

Or just use the `--dump` option on the CLI:

```bash
aspect --dump /path/to/launch.view
```

Options
-------

While creating `aspect.template` instance, you can pass an table of options as the constructor argument:
```lua
--- main options
local aspect = require("aspect.template").new({
    cache = true, 
    debug = true
})

--- render options
aspect:display("main.view", vars, {
    time_zone = 3 * 3600 
})
```


### Option `debug`

```lua
debug = boolean
```

When set to `true`, templates generates notices in some obscure situations. Also:

- enables `dump` function.
- enables compile-time and runtime notices.

Context:

- main options
- render options

### Option `loader`

```lua
loader = func
```
where `func` is
```lua
--- @param name string the template name
--- @param tpl aspect.template current aspect instance
--- @return string aspect template code
--- @return string error message
function func(name, tpl)  end
```
`loader` is used for loading templates from any resource such as the file system or databases.

Return `nil, nil` if no template found.

### Option `luacode_save`

```lua
luacode_save = func
```
where `func` is
```lua
--- @param name string the template name
--- @param luacode string lua code of template
--- @param tpl aspect.template current aspect instance
function func(name, luacode, tpl)  end
```

Function is used for saving compiled lua code of the template.

### Option `luacode_load`

```lua
luacode_load = func
```
where `func` is
```lua
--- @param name string the template name
--- @param tpl aspect.template current aspect instance
--- @return string|nil lua code of template
function func(name, tpl)  end
```

Function is used for loading compiled lua code of the template.

### Option `bytecode_save`

```lua
bytecode_save = func
```
where `func` is
```lua
--- @param name string the template name
--- @param bytecode string bytecode of template
--- @param tpl aspect.template current aspect instance
function func(name, bytecode, tpl)  end
```

Function is used for saving byte-code of the template.

### Option `bytecode_load`

```lua
luacode_load = func
```
where `func` is
```lua
--- @param name string the template name
--- @param tpl aspect.template current aspect instance
--- @return string|nil bytecode of template
function func(name, tpl)  end
```

Function is used for loading byte-code of the template.

### Option `autoescape`

```lua
autoescape = boolean
```

Option enables or disables auto-escaping with 'html' strategy. 

Context:

- main options
- render options

### Option `env`

```lua
env = table_or_function
```

Option sets the environment to be used by all templates (for current Aspect instance).

Context:

- main options
- render options

### Option `cache`

```lua
cache = table_or_boolean
```

Option enables or disables in-memory cache of templates objects. If this parameter is a table, then it will be used to store the cache. 

- `true` - enable cache
- `false` or `nil` — disable cache, load templates every call.
- `table` (using as `table<string,aspect.view>`) with custom view storage or object with `__newindex` and `__index` (default)

Context:

- main options

### Option `cache_version`

```lua
cache_version = any
```

Option set (lua code or byte-code) cache version. If change version all cache will be invalidated.

Context:

- main options

### Option `time_zone`

```lua
time_zone = number
```

Option sets UTC offset in seconds. For example Tokyo (+9 UTC) has offset `9 * 60 * 60` or `32400`. See [date](./filters/date.md).

Context:

- main options
- render options

### Option `locale`

```lua
locale = string
```

Option set locale ISO identifier. For example `en`, `de`, `ru`

Context:

- main options
- render options


### Option `build_stats`

```lua
build_stats = boolean
```

Option enables runtime statistics aggregator. Statistic stores in `aspect.template` object after compilation of the template. 

Context:

- render options

Global Config
-------------

### Configure JSON

Customize JSON encoder and decoder

```lua
local json = require("aspect.config").json
json.encode = json_encode_function
json.decode = json_decode_function
```

### Configure UTF8

Customize UTF8 binding

```lua
local utf8 = require("aspect.config").utf8
utf8.len   = utf8_len_function
utf8.lower = utf8_lower_function
utf8.upper = utf8_upper_function
utf8.sub   = utf8_sub_function
utf8.match = utf8_match_function
```

### Configure default environment

Cache
-----

Aspect templating engine has 3 cache levels:

1. lua code cache — normal (Aspect's functions `luacode_load` and `luacode_save`).
2. byte code cache — fast (Aspect's functions `bytecode_load` and `bytecode_save`).
3. `aspect.view` object cache (internal) — fastest (Aspect's property `cache`)

Cache stages:

0. _Require the template_
1. Get `aspect.view` from internal (table in the `aspect.template`) cache. If not found ...
2. ... get bytcode using `bytecode_load` function. If failed ...
3. ... get lua code using `luacode_load` function. If failed ...
4. ... _get template source code using `loader` function. Compile it._
5. Save lua code using `luacode_save` function.
6. Save bytcode using `bytecode_save` function.
7. Save `aspect.view` into internal (table in the `aspect.template`) cache.
8. _Render the template_

```lua
local aspect = require("aspect.template")

local template = aspect.new({
    cache = true -- enable internal lua in-memory cache 
})
template.bytecode_load = function (name, aspect)
    -- load bytecode from nginx shared dictionary
    return ngx.shared["cache"]:get(name)
end
template.luacode_load = function (name, aspect)
    -- load lua code from redis
    return redis:get(name)
end
template.luacode_save = function (name, luacode, aspect)
    -- save lua code into redis
    redis:set(name, luacode)
end
template.bytecode_save = function (name, bytecode, aspect)
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
aspect.loader = require("aspect.loader.filesystem").new("/var/project/templates")
```

The code bellow

```lua
aspect:display("pages/about.html", vars)
```

loads `/var/project/templates/pages/about.html` template.

### Resty loader

```lua
aspect.loader = require("aspect.loader.resty").new("/.templates/")
```

The code bellow

```lua
aspect:display("pages/about.html", vars)
```

loads `/.templates/pages/about.html` template (via [ngx.location.capture](https://github.com/openresty/lua-nginx-module#ngxlocationcapture)).

### Array loader

```lua
local tpls = require("aspect.loader.array").new()

tpls["dashboard.tpl"] = [[ ... template ... ]]
tpls["theme.tpl"] = [[<html> ... template ... </html>]]

aspect.loader = tpls
```

Extending
---------

### Add tags

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

See [aspect.tags](https://github.com/unifire-app/aspect/tree/master/src/aspect/tags.lua) for more examples.

### Add filters

```lua
local filters = require("aspect.filters")

filters.add("foo", {
    input = "any", -- input value type
    output = "string", -- output value type
    -- define foo's arguments
    args = {
        [1] = {name = "arg1", type = "string"}, 
        [2] = {name = "arg2", type = "number"}
    }
}, function (v, arg1, arg2) 

end)
```

See [aspect.filters](https://github.com/unifire-app/aspect/tree/master/src/aspect/filters.lua) for more examples.

### Add functions

Add function `{{ foo(arg1=x, arg2=y) }}`:

```lua
local funcs = require("aspect.funcs")

--- add {{ foo(arg1, arg2) }}
funcs.add("foo", {
    -- Define foo's arguments
    args = {
        [1] = {name = "arg1", type = "string"},
        [2] = {name = "arg2", type = "number"},
    },
    --- Optional. The function will be called when the template is compiled.
    --- @param compiler aspect.compiler
    --- @param args table
    parser = function (compiler, args)
        -- ...
    end
}, function (__, args) 
    -- ...
end)
```

See [aspect.funcs](https://github.com/unifire-app/aspect/tree/master/src/aspect/funcs.lua) for more examples.

### Add tests

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

See [aspect.tests](https://github.com/unifire-app/aspect/tree/master/src/aspect/tests.lua) for more examples.

### Add operators

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

Don't forget add `bitop` package to global environment using [config.env](#configure-env):

```lua
require("aspect.config").env.bit = bitop or require("bitop")
```

See [aspect.ast.ops](https://github.com/unifire-app/aspect/tree/master/src/aspect/ast/ops.lua) for more examples.

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
    Unacceptable condition!
{% end %}
```

Example do nothing because `zero` will be casted to `true` (`"0"` not 'empty').

Add behaviour for `0`

```lua
local is_false = require("aspect.config").is_false
is_false['0'] = true
```
 
Now example output `Unacceptable condition!` because `zero` will be casted to false.

### Empty string behaviour

Configure `aspect.config.is_empty_string` table. Indicate which values ​​are empty string or values ​​with specific metatable.

```lua
local is_empty_string = require("aspect.config").is_empty_string
is_empty_string[ngx.null] = true
is_empty_string[getmetatable(cbson.null())] = true
```

### Number behaviour

Configure `aspect.config.is_n` table.  Indicate which objects can behave like numbers.

```lua
local is_n = require("aspect.config").is_n
is_n[getmetatable(cbson.number(0))] = 0
```

## Custom escaper

Add custom escaper via config, using escaper name: 

```lua
require("aspect.config").escapers.csv = function(value) 
    -- ... returns escaped value
end
```

```twig
{{ data.raw|e("csv") }}
```

Date processing
---------------

### strtotime

Parse about any textual datetime description into a Unix timestamp:

```lua
local strtotime = require("aspect.date").strtotime
local ts, info = strtotime("2009-02-13 23:31:30")
```

Table `info` contains more information about date (day, month, year, hour, min, sec, time zone offset) 

### Date localization

Add or change month and day of the week localizations.  

**Month localization** 

For parser ([required utf8 module](#configure-utf8))
```lua
local months = require("aspect.config").date.months
months["дек"] = 12          -- add short name of december on russian
months["декабрь"] = 12      -- add long name of december on russian
months["dic"] = 12          -- add short name of december on spain
months["diciembre"] = 12    -- add long name of december on spain
-- ...
```
For formatter (utf8 module NOT required)
```lua
local months_locale = require("aspect.config").date.months_locale
months_locale["ru"] = {        -- add Russian name of month 
    [1]  = {"Янв", "Январь"},  -- {"Jan", "January"}
    [2]  = {"Фев", "Февраль"}, -- {"Feb", "February"}
    [3]  = {"Мар", "Март"},    -- {"Mar", "March"}
    --- ...
}
```
There 1 - january, 12 - december. Index 1 — short name of month, index 2 - full name of month.

**Week localization**

For formatter (utf8 module NOT required)
```lua
local week_locale = require("aspect.config").date.week_locale
week_locale["ru"] = {  -- add Russian day of the week
    [1] = {"Пн", "Понедельник"},  -- {"Mon", "Monday"}
    [2] = {"Вт", "Вторник"},      -- {"Tue", "Tuesday"}
    [3] = {"Ср", "Среда"},        -- {"Wed", "Wednesday"}
    --- ...
}
```
There 1 - monday, 7 - sunday (see ISO8601 part 2.2.8)

### Date parser

Add or change date parsers. For example add parser for date like `2009Y02M13D23h31m30s+0230z` (it is `2009-02-13 23:31:30 UTC+02:30`)

```lua
local date = require("aspect.date")
table.insert(date.parsers.date, { -- parse date segment
    pattern = "(%d%d%d%d)Y(%d%d)M(%d%d)D",
    match = function(y, m, d)
        return {year = tonumber(y), month = tonumber(m), day = tonumber(d)}
    end 
})
table.insert(date.parsers.time, { -- parse time segment
    pattern = "(%d%d)h(%d%d)m(%d%d)s",
    match = function(h, m, s)
        return {hour = tonumber(h), min = tonumber(m), sec = tonumber(s)}
    end 
})
table.insert(date.parsers.zone, { -- parse offset/timezone offset
    pattern = "([+-]%d%d)(%d?%d?)z",
    match = function(h, m)
        return {offset = tonumber(h) * 60 * 60 + (tonumber(m) or 0) * 60} -- seconds 
    end 
})
```  

How parsers work:

- take `date` parser.
  - Iterate by patterns.
  - When the pattern matches, the `match` function will be called.
  - `Match` function returns table like `os.date("*t")` if success, nil if failed (if nil resume 1.1)
- take `time` parser. search continues with the next character after matched `date`
  - Iterate by patterns.
  - When the pattern matches, the `match` function will be called.
  - `Match` function returns table like `os.date("*t")` if success, nil if failed (if nil resume 2.1)
- take `zone` parser. search continues with the next character after matched `time`
  - Iterate by patterns.
  - When the pattern matches, the `match` function will be called.
  - `Match` function returns table with key `offset` if success, nil if failed (if nil resume 3.1)
- calculate timestamp

See `date.parsers` for more information.

### Date format aliases

Add symbol `R` (`$R`) witch is `%I:%M:%S %p`

```lua
local aliases = require("aspect.config").date.aliases
aliases["R"] = "%I:%M:%S %p"
```

Iterator and countable objects
-------------------------------

The `Aspect` implements custom iterators as in Lua 5.2+ - through the metatable and `__pairs()` function. 
Works for all lua/luajit versions.

For example see [range iterator](https://github.com/unifire-app/aspect/tree/master/src/aspect/src/aspect/utils/range.lua).

As in Lua 5.2+, the Aspect allows to determine the length of objects through the `__len()` function. 
Works for all lua/luajit versions.

<!-- {% endraw %} -->
