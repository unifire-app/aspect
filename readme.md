Aspect Lua Template
===================

Features
--------

* Syntax: [Twig2](https://twig.symfony.com/doc/2.x/templates.html) and [Jinja2](https://jinja.palletsprojects.com/en/2.10.x/templates/)
* Pipelines: generate pipe output from huge data
* ByteCode cache
* LuaCode cache
* Run in sandbox
* User-friendly

Basic
-----

* `{{ ... }}`
* `{% ... %}`
* `{# ... #}`

Tags
----

* [set](./docs/tags/set.md) — assign values to variables
* [if, elseif, elif, else](./docs/tags/if.md) — conditional statement
* [for, else](./docs/tags/for.md) — loop over each item in a sequence.
* macro, import, from
* [include](./docs/tags/include.md) — includes a template and returns the rendered content
* block, extends
* apply

Filters
-------

* abs
* batch(size)
* column(column)
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