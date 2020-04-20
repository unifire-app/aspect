Features
========

<!-- {% raw %} -->

* Sandboxed execution mode. Every aspect of the template execution is monitored and explicitly whitelisted or blacklisted, 
  whatever is preferred. This makes it possible to execute untrusted templates.
* Powerful [automatic HTML escaping](./syntax.md#escape-control) system for cross site scripting prevention.
* [Template inheritance](./syntax.md#template-inheritance) makes it possible to use the same or a similar layout for all templates.
* High performance with just in time compilation to Lua bytecode. 
  Aspect will translate your template sources on first load into Lua bytecode for best runtime performance.
* Easy to debug with a debug system that integrates template compile and runtime errors into the standard Lua traceback system.
* [Configurable syntax](./api.md#extending).
* [Iterator supported](./api.md#iterator) and countable objects.
* Supports lua 5.1/5.2/5.3 and luajit 2.0/2.1 (including OpenResty)
* Keys sequence `a.b.c.d` returns `nil` if variable `a` or any keys doesn't exits.
* [Two level cache](./api.md#cache) (lua level and bytecode level).
* Date support.
* [Chain rendering](./api.md#rendering-templates) (renders data chunk by chunk).
* Change some Lua behaviours (see below).

Behaviours
==========

## Working with strings

| Value         | String evaluation  |
|---------------|--------------------|
| `nil`         | empty string       |
| cjson.null    | empty string       |
| cbson.null()  | empty string       |
| lyaml.null    | empty string       |
| yaml.null     | empty string       |
| ngx.null      | empty string       |
| msgpack.null  | empty string       |
| other value   | `tostring(...)`    |

You may [configure empty-string behavior](./api.md#empty-string-behaviour).

## Working with numbers

| Value                    | Number evaluation         |
|--------------------------|---------------------------|
| empty string             | 0                         |
| string "0" or '0'        | 0                         |
| false                    | 0                         |
| true                     | 1                         |
| any table                | 0                         |
| nil                      | 0                         |
| userdata                 | `tonumber(tostring(...))` |
| non numeric string       | 0                         |
| string                   | `tonumber(...)`           |

You may [configure number behavior](./api.md#number-behaviour).

## Working with booleans

The rules to determine if an expression is `true` or `false` are (edge cases):

| Value                       | Boolean evaluation |
|-----------------------------|--------------------|
| empty string                | false              |
| other string                | true               |
| numeric zero                | false              |
| whitespace-only string      | true               |
| string "0" or '0'           | true               |
| empty table                 | false              |
| nil                         | false              |
| non-empty table             | true               |
| table with `__toboolean`    | `__toboolean()`    |
| table with `__len`        | `__len() ~= 0`   |
| cjson.null                  | false              |
| cbson.null()                | false              |
| lyaml.null                  | false              |
| yaml.null                   | false              |
| ngx.null                    | false              |
| msgpack.null                | false              |
| userdata with `__toboolean` | `__toboolean()`    |
| userdata with `__len`     | `__len() ~= 0`   |

Functions `__toboolean()` and `__len()` should be a part of the metatable. 

## Working with cycles

Aspect allows define own object-iterators via metatable.

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
| table                    | iterate with `pairs()` |

The function `__pairs()` should be a part of the metatable 
and compatible with basic function `pairs()` (returns `iterator`, `key`, `value`) 

## Working with counting

| Value                    | Number evaluation    |
|--------------------------|----------------------|
| string                   | `string.len(...)`    |
| empty table              | 0                    |
| number                   | 0                    |
| nil                      | 0                    |
| true/false               | 0                    |
| userdata                 | 0                    |
| table                    | count of keys        |
| table with `__len`     | `__len(...)`       |
| table with `__pairs`     | invoke `__pairs()` and count elements |
| userdata with `__len`  | `__len(...)`       |
| userdata with `__pairs`  | invoke `__pairs()` and count elements |

<!-- {% endraw %} -->