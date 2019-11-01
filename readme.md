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

Basic
-----

* `{{ ... }}` - variable or expression
* `{% ... %}` — control tag
* `{# ... #}` - comment

Tags
----

* [set](./docs/tags/set.md) — assign values to variables
* do
* [if, elseif, elif, else](./docs/tags/if.md) — conditional statement
* [for, else](./docs/tags/for.md) — loop over each item in a sequence.
* [macro](./docs/tags/macro.md), [import](./docs/tags/macro.md#importing-macros), [from](./docs/tags/macro.md#importing-macros)
* [include](./docs/tags/include.md) — includes a template and returns the rendered content
* [extends](./docs/tags/extends.md), [block](./docs/tags/extends.md#block), [use](./docs/tags/extends.md#use) — template inheritance ([read more](./docs/inheritance.md))
* apply
* embed
* autoescape
* deprecated
* verbatim aka ignore
* scope

Filters
-------

* [abs](./docs/filters.md#abs)
* batch(size)
* [column(column)]()
* date(format)
* date_modify(offset)
* escape(type), e(type)
* default(value)
* first
* last
* format(...)
* format_number(opts)
* markdown_to_html(opts)
* join(delim, last_delim)
* json_encode
* keys
* length
* lower
* upper
* map(formatter)
* merge(items)
* nl2br
* raw
* replace
* split(delim, count)
* striptags(tags)
* url_encode
* strip
* range(low, high, step)

Tests
-----

* [defined](./docs/tests/defined.md)