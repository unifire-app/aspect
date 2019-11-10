
Get started
-----------

```lua
local aspect = require("aspect.template")

local tmpl = aspect.new()
tmpl.loader = function (name)
    --- load template body by name
    return app:load_template(name) 
end

tmpl:display("dashboard.tpl", {
    title = "hello world",
    data = app:get_data()
})
```


Cache
-----

Cache stages:

0. _Require the template_
1. Get `aspect.view` from internal (table in the `aspect.template`) cache.
2. Get bytcode using `bytecode_load` function.
3. Get lua code using `luacode_load` function.
4. _Get template source code using `loader` function._
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
    return ngx.shared["cache"]:get(name)
end
template.luacode_load = function (t, name)
    return redis:get(name)
end
template.luacode_save = function (t, name, luacode)
    -- save lua code into redis e.g.
    redis:set(name, luacode)
end
template.bytecode_save = function (t, name, bytecode)
    -- cache bytecode into nginx shared dictionary
    ngx.shared["cache"]:set(name, bytecode)
end
```

Use custom table for internal cache:

```lua
local aspect = require("aspect.template")
local template = aspect.new({
    cache = _G.tpls -- use global tpls table for storing aspect.view
})
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

Add tests `foo` and `bar`

```lua
local tests = require("aspect.tests")

tests.fn.is_foo = function (v)
   -- return boolean
end

tests.args.is_bar = true -- bar tests has expression
tests.fn.is_bar = function (v, expr)
   -- return boolean
end
```

Result:

```twig
{{ a is foo }}
{{ a is bar(c) }}
```

See [aspect.tests](../src/aspect/tests.lua) for more examples.

Add operators
-------------

For example add bitwise operator `&`: 

```lua
local ops = require("aspect.ast.ops")

--- push new operator to operators array
--- @see aspect.ast.op
table.insert(ops, {
    token = "&",
    order = 7,
    l = "number",
    r = "number",
    out = "number",
    out = "binary",
    pack = function (left, right)
        return "BitOp.and(" .. left .. ", " .. right .. ")"
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