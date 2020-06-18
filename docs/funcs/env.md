---
layout: page
title: Functions › env
---

[← functions](./../env.md)

<!-- {% raw %} -->

`env` returns the environment value for a given string:

```twig
{{ some_date|date(env('config.date.format')) }}
```

All environment values set using the [env option](./../api.md#options) when creating 
a template engine or when starting a template render

Use the `defined` test to check if a environment value is defined:

```twig
{% if env('req.args.page') is defined %}
    ...
{% endif %}
```

<!-- {% endraw %} -->