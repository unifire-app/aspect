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

<!-- <img align="right" src="./aspect.png" width="200"> -->


<div class="row">
<div class="col-lg-6" markdown="1">

## Synopsis
{:.mt-lg-0}

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
    </body>
</html>
```

Aspect also has a [console tool](./cli.md) for rendering data

```bash
$ aspect /path/to/data.json /path/to/template.tpl
```

</div>
<div class="col-lg-6" markdown="1">

## Installation
{:.mt-lg-0}

The recommended way to install Aspect is via LuaRocks:

```bash
luarocks install aspect
```

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
- [Tests](./tests.md)

</div>
<div class="col-lg-6" markdown="1">

**For developers:**

- [Lua API](./api.md)
- [CLI](./cli.md)
- [Extending](./api.md#extending)

</div>
</div>

</div>
</div>

## Features

The key-features are...
* _Well known_: The most popular syntax is used - 
  [Twig](https://twig.symfony.com/) compatible, [Jinja](https://jinja.palletsprojects.com/) similar, [Liquid](https://shopify.github.io/liquid/) like.
* _Fast_: Aspect compiles templates down to plain optimized Lua code. 
  Moreover, Lua code compiles into bytecode - the fastest representation of a template.
* _Secure_: Aspect has a sandbox mode to evaluate all template code. 
  This allows Aspect to be used as a template language for applications where users may modify the template design.
* _Flexible_: Aspect is powered by a flexible lexer and parser. 
  This allows the developer to define their own custom tags, filters, functions and operators, and to create their own DSL.
* _Supports_ lua 5.1/5.2/5.3 and luajit 2.0/2.1
* Has [console renderer](./cli.md).
* No dependencies. Pure Lua. 
* Sandboxed execution mode. Every aspect of the template execution is monitored and explicitly whitelisted or blacklisted, 
  whatever is preferred. This makes it possible to execute untrusted templates.
* Powerful [automatic HTML escaping](./syntax.md#html-escaping) system for cross site scripting prevention.
* [Template inheritance](./syntax.md#template-inheritance) makes it possible to use the same or a similar layout for all templates.
* High performance with just in time compilation to Lua bytecode. 
  Aspect will translate your template sources on first load into Lua bytecode for best runtime performance.
* Easy to debug with a debug system that integrates template compile and runtime errors into the standard Lua traceback system.
* [Configurable syntax](./api.md#extending).
* [Iterator supported and countable objects](./api.md#iterator-and-countable-objects).
* Supports lua 5.1/5.2/5.3 and luajit 2.0/2.1 (including OpenResty)
* Keys sequence `a.b.c.d` returns `nil` if variable `a` or any keys doesn't exits.
* [Two level cache](./api.md#cache) (lua level and bytecode level).
* Date support.
* [Chain rendering](./api.md#rendering-templates) (renders data chunk by chunk).
* Change some [Lua behaviours](./spec.md).

<!-- {% endraw %} -->
