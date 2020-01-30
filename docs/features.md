Features
========

* Supports lua 5.1/5.2/5.3 and luajit 2.0/2.1 (including OpenResty)
* The template is built in such a way as to save maximum memory when it is executed, 
  even if the iterator provides a lot of data.
* Keys sequence `a.b.c.d` returns `nil` if variable `a` or any keys doesn't exits.
* [Template extending](./syntax.md#template-inheritance).
* [Two level cache](./api.md#cache) (lua level and bytecode level).
* Custom iterator supported.
* [Chain rendering](./api.md#rendering-templates) (renders data chunk by chunk).
* Change some Lua behaviours (see below).

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

You may [configure number
 behavior](./api.md#number-behaviour).

## Working with booleans

The rules to determine if an expression is `true` or `false` are (edge cases):

| Value                    | Boolean evaluation |
|--------------------------|--------------------|
| empty string             | false              |
| numeric zero             | false              |
| whitespace-only string   | true               |
| string "0" or '0'        | true               |
| empty table              | false              |
| nil                      | false              |
| non-empty table          | true               |
| table with `__toboolean` | `__toboolean()`    |
| table with `__count`     | `__count() ~= 0`   |
| cjson.null               | false              |
| cbson.null()             | false              |
| lyaml.null               | false              |
| yaml.null                | false              |
| ngx.null                 | false              |
| msgpack.null             | false              |

Functions `__toboolean()` and `__count()` should be a part of the metatable. 

## Working with cycles

Aspect allows define own object-iterators via metatable.

| Value                    | Action               |
|--------------------------|----------------------|
| string                   | not iterate          |
| empty table              | not iterate          |
| number                   | not iterate          |
| nil                      | not iterate          |
| true/false               | not iterate          |
| userdata                 | not iterate          |
| userdata with `__pairs`  | iterate with `__pairs()` |
| table                    | iterate with `pairs()` |
| table with `__pairs`     | iterate with `__pairs()` instead of `pairs()` |

The function `__pairs()` should be a part of the metatable 
and compatible with basic function `pairs()` (returns `iterator`, `key`, `value`) 

## Working with counting

| Value                    | Number evaluation    |
|--------------------------|----------------------|
| string                   | `strlen(...)`        |
| empty table              | 0                    |
| number                   | 0                    |
| nil                      | 0                    |
| true/false               | 0                    |
| userdata                 | 0                    |
| table                    | count of keys        |
| table with `__count`     | `__count(...)`       |
| table with `__pairs`     | iterate with `__pairs()` and count elements |
| userdata with `__count`  | `__count(...)`       |
| userdata with `__pairs`  | iterate with `__pairs()` and count elements |