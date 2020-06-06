---
layout: page
title: Specification
---

<!-- {% raw %} -->

- **What is it**: templater
- **Syntax**: twig, jinja, django, liquid
- **Language**: Lua 5.1+
- **Dependency**: none
- **Compiler**: [simple tokenizer](https://github.com/unifire-app/aspect/blob/master/src/aspect/tokenizer.lua) + [AST](https://github.com/unifire-app/aspect/blob/master/src/aspect/ast.lua)
- **Unittest**: [busted](https://olivinelabs.com/busted/)

## Limitations

- New (local) variables cannot be called by the following names (by internal limitation): `and`, `break`, `do`, `else`, `elseif`, 
  `end`, `false`, `for`, `function`, `if`, `in`, `local`, `nil`, `not`, `or`, `repeat`, `return`, `then`, 
  `true`, `until`, `while`.

## Working with keys

Keys sequence `a.b.c` returns `nil` if variable `a` or any other keys (`b` or `c`) doesn't exits.
The sequence of keys `a.b.c` may be represented as lua code
```lua
if a and is_table(a) and a.b and is_table(a.b) and a.b.c then
    return a.b.c
else
    return nil
end
``` 

## Working with strings

In case the value should be converted to a string.

| Value         | String evaluation  | Info  |
|---------------|--------------------|-------|
| `nil`         | empty string       |       |
| cjson.null    | empty string       | see [cjson](https://github.com/openresty/lua-cjson) |
| cbson.null()  | empty string       | see [cbson](https://github.com/isage/lua-cbson) |
| lyaml.null    | empty string       | see [lyaml](https://github.com/gvvaughan/lyaml) |
| yaml.null     | empty string       | see [yaml](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/yaml/) |
| ngx.null      | empty string       | see [ngx_lua](https://github.com/openresty/lua-nginx-module#core-constants) |
| msgpack.null  | empty string       | see [msgpack](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/msgpack/) |
| box.NULL      | empty string       | see [tarantool box](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/box_null/) |
| other value   | `tostring(...)`    |

You may [configure empty-string behavior](./api.md#empty-string-behaviour).

## Working with numbers

- for [math operations](./syntax.md#math-operators)
- in case the value should be converted to a number.

| Value                    | Number evaluation         | Info                                   |
|--------------------------|---------------------------|----------------------------------------|
| empty string             | 0                         |                                        |
| string "0" or '0'        | 0                         |                                        |
| false                    | 0                         |                                        |
| true                     | 1                         |                                        |
| any table                | 0                         |                                        |
| nil                      | 0                         |                                        |
| userdata                 | `tonumber(tostring(...))` | if result is `nil` then `0` will be used |
| string                   | `tonumber(...)`           | if result is `nil` then `0` will be used |

You may [configure number behavior](./api.md#number-behaviour).

## Working with booleans

The rules to determine if an expression is `true` or `false` are (edge cases):

| Value                       | Boolean evaluation | Info   |
|-----------------------------|--------------------|--------|
| empty string                | false              |        |
| other string                | true               |        |
| numeric zero                | false              |        |
| whitespace-only string      | true               |        |
| string "0" or '0'           | true               |        |
| nil                         | false              |        |
| table with `__toboolean`    | `__toboolean()`    |        |
| table with `__len`          | `__len() ~= 0`     |        |
| empty table                 | false              |        |
| non-empty table             | true               |        |
| cjson.null                  | false              | see [cjson](https://github.com/openresty/lua-cjson) |
| cjson.empty_array           | false              | see [cjson](https://github.com/openresty/lua-cjson) |
| cbson.null()                | false              | see [cbson](https://github.com/isage/lua-cbson) |
| cbson.null()                | false              | see [cbson](https://github.com/isage/lua-cbson) |
| cbson.array()               | false              | see [cbson](https://github.com/isage/lua-cbson) |
| lyaml.null                  | false              | see [lyaml](https://github.com/gvvaughan/lyaml) |
| yaml.null                   | false              | see [yaml](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/yaml/) |
| ngx.null                    | false              | see [ngx_lua](https://github.com/openresty/lua-nginx-module#core-constants) |
| msgpack.null                | false              | see [msgpack](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/msgpack/) |
| box.NULL                    | false              | see [tarantool box](https://www.tarantool.io/en/doc/2.4/reference/reference_lua/box_null/) |
| userdata with `__toboolean` | `__toboolean()`    |        |
| userdata with `__len`       | `__len() ~= 0`     |        |

Functions `__toboolean()` and `__len()` should be a part of the metatable.
 
You may [configure `false` behavior](./api.md#condition-behaviour).

## Working with cycles

Aspect supports iterators from Lua 5.2+ versions for Lua 5.1 and LuaJIT versions.

| Value                    | Action               |
|--------------------------|----------------------|
| string                   | not iterate          |
| empty table              | not iterate          |
| number                   | not iterate          |
| nil                      | not iterate          |
| true/false               | not iterate          |
| userdata with `__pairs`  | iterate with `__pairs()` |
| userdata                 | not iterate          |
| table with `__pairs`     | iterate with `__pairs()` instead of `pairs()` |
| other table              | iterate with `pairs()` |

The function `__pairs()` should be a part of the metatable 
and compatible with basic function `pairs()` (returns `iterator`, `key`, `value`) 

## Working with counting

When it is necessary to count the number of elements (filter `length` or variable `loop.length`).

| Value                    | Number evaluation    |
|--------------------------|----------------------|
| string                   | `string.len(...)`    |
| empty table              | 0                    |
| number                   | 0                    |
| nil                      | 0                    |
| true/false               | 0                    |
| userdata                 | 0                    |
| table with `__len`       | `__len(...)`         |
| table with `__pairs`     | invoke `__pairs()` and count elements |
| other tables             | count of keys        |
| userdata with `__len`    | `__len(...)`         |
| userdata with `__pairs`  | invoke `__pairs()` and count elements |

<!-- {% endraw %} -->