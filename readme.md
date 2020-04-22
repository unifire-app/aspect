Aspect Lua Template
===================

[![Build Status](https://travis-ci.org/unifire-app/aspect.svg?branch=master)](https://travis-ci.org/unifire-app/aspect)
[![codecov](https://codecov.io/gh/unifire-app/aspect/branch/master/graph/badge.svg)](https://codecov.io/gh/unifire-app/aspect)
[![Luarocks](./assets/luarocks.svg)](https://luarocks.org/modules/unifire/aspect)

<!-- {% raw %} -->

**Aspect** is a compiling (to Lua code and/or bytecode) templating engine for Lua and OpenResty. No dependencies. Pure Lua.

#### [Syntax](./docs/syntax.md) | [Tags](./docs/tags.md) | [Filters](./docs/filters.md) | [Functions](./docs/funcs.md) | [Tests](./docs/tests.md)


<img align="right" src="./assets/aspect.png" width="128">

The key-features are...
* _Well known_: The most popular syntax is used - 
  [Twig](https://twig.symfony.com/doc/2.x/templates.html) compatible, [Jinja](https://jinja.palletsprojects.com/en/2.10.x/templates/)/[Liquid](https://shopify.github.io/liquid/) like.
* _Fast_: Aspect compiles templates down to plain optimized Lua code. 
  Moreover, Lua code compiles into bytecode - the fastest representation of a template.
* _Secure_: Aspect has a sandbox mode to evaluate all template code. 
  This allows Aspect to be used as a template language for applications where users may modify the template design.
* _Flexible_: Aspect is powered by a flexible lexer and parser. 
  This allows the developer to define their own custom tags, filters, functions and operators, and to create their own DSL.
* _Supports_ lua 5.1/5.2/5.3 and luajit 2.0/2.1 (with OpenResty)
* Has [console renderer](./docs/cli.md).
* **[List of all features](./docs/features.md)**

Synopsis
--------

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

Aspect also has a [console tool](./docs/cli.md) for rendering data

```bash
$ aspect /path/to/data.json /path/to/template.tpl
```

[API Documentation](./docs/api.md)
--------------------

* [Installation](./docs/installation.md)
* [Basic Usage](./docs/api.md#basic-api-usage)
* [Configuration](./docs/api.md#options)
* [Cache](./docs/api.md#cache)
* [Loaders](./docs/api.md#loaders)
* [Extending](./docs/api.md#extending)
* [Iterator and countable objects](./docs/api.md#iterator-and-countable-objects)
* [Command Line](./docs/cli.md)

[Syntax](./docs/syntax.md)
------

* [Variables](./docs/syntax.md#variables)
* [Expression](./docs/syntax.md#expressions)
* [Filters](./docs/syntax.md#filters)
* [Functions](./docs/syntax.md#functions)
* [Named Arguments](./docs/syntax.md#named-arguments)
* [Control Structure](./docs/syntax.md#control-structure)
* [Comments](./docs/syntax.md#comments)
* [Template Inheritance](./docs/syntax.md#template-inheritance)
* [Macros](./docs/syntax.md#macros)
* [Expressions](./docs/syntax.md#expressions)
* [Operators](./docs/syntax.md#operators)
* [Whitespace control](./docs/syntax.md#whitespace-control)
* [HTML Escaping](./docs/syntax.md#html-escaping)
* [Tags](./docs/tags.md)
* [Filters](./docs/filters.md)
* [Functions](./docs/funcs.md)
* [Tests](./docs/tests.md)

<!-- {% endraw %} -->