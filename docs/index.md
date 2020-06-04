---
layout: full
homepage: true
disable_anchors: true
description: Aspect is a compiling template engine for Lua and LuaJIT.
---

<!-- {% raw %} -->

**Aspect** a compiling (to Lua code and bytecode) a template engine for Lua and LuaJIT. Adapted to work with OpenResty and Tarantool. 
Lua itself is a simple language, but with many limitations and conventions. 

Aspect makes it easy to work with Lua, letting you focus on the design of templates. 
Template syntax is very popular. This syntax is used in Twig, Jinja, Django, Liquid.

**Yet another template engine?** Yes. But more powerful than any other template engines. Just check out all the [features](#features).

<!-- <img align="right" src="./aspect.png" width="200"> -->


<div class="row">
<div class="col-lg-6" markdown="1">

## Synopsis
{:.mt-lg-0}

[Template syntax](./syntax.md):

```twig
<!DOCTYPE html>
<html>
    <head>
        {% block head %}
            <title>{{ page.title }}</title>
        {% endblock %}
    </head>
    <body>
        {% block content %}
            <ul id="navigation">
            {% for item in navigation %}
                <li><a href="{{ item.href }}">
                    {{- item.caption|escape -}}
                </a></li>
            {% endfor %}
            </ul>
    
            <h1>My Webpage</h1>
            {{ page.body }}
        {% endblock %}
        <footer>{% include "footer.view" %}</footer>
    </body>
</html>
```

[Lua API](./api.md):

```lua
local aspect = require("aspect.template").new(options)
local result, error = aspect:eval("<div>Hello, {{ username }}", vars)
```

[Command line](./cli.md):

```bash
$ aspect /path/to/data.json /path/to/template.tpl
```

</div>
<div class="col-lg-6" markdown="1">

## Installation
{:.mt-lg-0}

**Using LuaRocks**

Installing Aspect using [LuaRocks](https://luarocks.org) is simple:

```bash
luarocks install aspect
```

**Without LuaRocks**

Or add `src/?.lua` to `package.path`:

```lua
package.path = '/path/to/aspect/src/?.lua;' .. package.path
```

## Documentation links

<div class="row">
<div class="col-lg-6" markdown="1">

**For template designers:**

- [Specification](./spec.md)
- [Template Syntax](./syntax.md)
- [Operators](./syntax.md#operators)
- [Tags](./tags.md)
- [Filters](./filters.md)
- [Functions](./funcs.md)
- [Tests](./tests.md)

</div>
<div class="col-lg-6" markdown="1">

**For developers:**

- [Lua API](./api.md)
- [CLI](./cli.md)
- [Extending](./api.md#extending)
- [Changelog](https://github.com/unifire-app/aspect/blob/master/changelog.md)

</div>
</div>

</div>
</div>

## Features

* _Well known_: Aspect uses the most popular template syntax. 
  [Twig](https://twig.symfony.com/) for PHP (maximum compatibility), [Jinja](https://jinja.palletsprojects.com/) for Python (minor differences), [Liquid](https://shopify.github.io/liquid/) for Ruby (minor syntax differences).
* _Fast_: Aspect compiles templates down to plain optimized Lua code. 
  Moreover, Lua code compiles into bytecode - the fastest representation of a template.
  Aspect will translate your template sources on first load into Lua bytecode for best runtime performance.
* _Safe_: Aspect always runs templates in the sandbox (empty environment) from where it is impossible to access the system packages.
  This allows Aspect to be used as a template language for applications where users may modify the template design.
* _Flexible_: Aspect is powered by a flexible parser and compiler. 
  This allows the developer to define their own custom [tags](api.md#add-tags), 
  [filters](api.md#add-filters), [functions](api.md#add-functions), [tests](api.md#add-tests) and [operators](api.md#add-operators).
* _Supports_ lua 5.1/5.2/5.3 and luajit 2.0/2.1 (including OpenResty).
* _Convenient_. Aspect makes it easy for users to work with templates. 
  It has [automatic type casting](spec.md#working-with-strings), [automatic checking](spec.md#working-with-keys) of a variable and its keys, 
  it changes some [annoying behavior](spec.md) of lua.
* _CLI_: Aspect has a [console command](./cli.md) for the template engine. 
  Generate configs and other files using popular syntax.
* _Cache_. Aspect has a [multi-level cache](./api.md#cache).
* _No dependencies_. No FFI. Pure Lua. 
* _Secure_. Aspect has powerful [automatic HTML escaping](./syntax.md#html-escaping) system for cross site scripting prevention.
* [Template inheritance](./syntax.md#template-inheritance) makes it possible to use the same or a similar layout for all templates.
* Easy to [debug](api.md#debug-templates) with a debug system that integrates template compile and runtime errors into the standard Lua traceback system.
* [Iterator supported and countable objects](./api.md#iterator-and-countable-objects).
* Date supports.
* [Chain rendering](./api.md#rendering-templates) (renders data chunk by chunk).

<!-- {% endraw %} -->
