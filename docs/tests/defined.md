---
layout: page
title: Tests › defined
---

[← tests](./../tests.md)

<!-- {% raw %} -->

`defined` checks if a variable is defined in the current context. 

```twig
{# defined works with variable names #}
{% if foo is defined %}
    ...
{% endif %}

{# and attributes on variables names #}
{% if foo.bar is defined %}
    ...
{% endif %}

{% if foo['bar'] is defined %}
    ...
{% endif %}
```
<!-- {% endraw %} -->