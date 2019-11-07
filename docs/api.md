
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

See `aspect.tags` for more details.

Add filters
-----------

Add functions
-------------

Condition behaviour
-------------------

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