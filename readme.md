Aspect Lua Template
===================

**Aspect** is a compiling (HTML) templating engine for Lua and OpenResty.

Features
--------

* Syntax: [Twig2](https://twig.symfony.com/doc/2.x/templates.html) and [Jinja2](https://jinja.palletsprojects.com/en/2.10.x/templates/)
* Available byte code cache (for luajit)
* Available lua code cache
* Safety: template always runs in sandbox.
* Resistant to unexpected data: data type checking before use.
* Big data is not a problem: data output can be pipelined, works without buffers, works with runtime small buffer (chunked) etc
* Easy to develop: detailed description of problems when they occur.
* Extensibility: adding your own tags, filters, functions, handlers.
* User-friendly: expected behavior at certain values (`0` or empty string always false etc)
* OpenResty supported.

Synopsis
--------

A template is a regular text file. 
It can generate any text-based format (HTML, XML, CSV, LaTeX, etc.). It doesn't have a specific extension, 
.html or .xml are just fine.

A template contains **variables** or **expressions**, which get replaced with values when the template is evaluated, 
and tags, which control the template's logic.

Below is a minimal template that illustrates a few basics. We will cover further details later on:

```twig
<!DOCTYPE html>
<html>
    <head>
        <title>My Webpage</title>
    </head>
    <body>
        <ul id="navigation">
        {% for item in navigation %}
            <li><a href="{{ item.href }}">{{ item.caption }}</a></li>
        {% endfor %}
        </ul>

        <h1>My Webpage</h1>
        {{ a_variable }}
    </body>
</html>
```
There are two kinds of delimiters: `{% ... %}` and `{{ ... }}`. 
The first one is used to execute statements such as for-loops, the latter outputs the result of an expression.

API
---

* Configuration
* Get template output
* Run template pipline output
* [Cache](./docs/api.md#cache)
* [Add tags](./docs/api.md#add-tags)
* [Add filter](./docs/api.md#add-filters)
* [Add functions](./docs/api.md#add-functions)
* Configure behaviors

Syntax
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

Tags
----

* [set](./docs/tags/set.md) — assign values to variables
* do
* [if, elseif, elif, else](./docs/tags/if.md) — conditional statement
* [for, else](./docs/tags/for.md) — loop over each item in a sequence.
* [macro](./docs/tags/macro.md), [import](./docs/tags/macro.md#importing-macros), [from](./docs/tags/macro.md#importing-macros)
* [include](./docs/tags/include.md) — includes a template and returns the rendered content
* [extends](./docs/tags/extends.md), [block](./docs/tags/extends.md#block), [use](./docs/tags/extends.md#use) — 
  template inheritance ([read more](./docs/syntax.md#template-inheritance))
* apply
* embed
* autoescape
* deprecated
* verbatim aka ignore
* scope

Filters
-------

* [abs](./docs/filters/abs.md)
* [batch(size)](./docs/filters/batch.md)
* [column(column)](./docs/filters/columns.md)
* [date(format)](./docs/filters/date.md)
* [date_modify(offset)](./docs/filters/date_modify.md)
* [escape(type), e(type)](./docs/filters/escape.md)
* [default(value, boolean)](./docs/filters/default.md)
* [first](./docs/filters/first.md)
* last
* [format(...)](./docs/filters/format.md)
* format_number(opts)
* markdown_to_html(opts)
* [join(delim, last_delim)](./docs/filters/join.md)
* [json_encode](./docs/filters/json_encode.md)
* [keys](./docs/filters/keys.md)
* [length](./docs/filters/length.md)
* [lower](./docs/filters/lower.md)
* [upper](./docs/filters/lower.md)
* map(formatter)
* merge(items)
* nl2br
* [raw](./docs/filters/raw.md)
* replace
* split(delim, count)
* striptags(tags)
* [trim](./docs/filters/trim.md)
* url_encode
* strip

Functions
---------

* [parent()](./docs/tags/extends.md#parent)
* [block(name, template)](./docs/tags/extends.md#block-function)
* [range(low, high, step)](./docs/funcs/range.md)
* [date(date)](./docs/funcs/date.md)

Tests
-----

* [defined](./docs/tests/defined.md)