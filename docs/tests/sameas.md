---
layout: page
title: Tests › same as
---

[← tests](./../tests.md)

<!-- {% raw %} -->

`same as` checks if a variable is the same as another variable. This is the equivalent to == in Lua:

```twig
{% if foo.attribute is same as(false) %}
    the foo attribute really is the 'false' value
{% endif %}
```

<!-- {% endraw %} -->