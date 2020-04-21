Test `same as`
=============

<!-- {% raw %} -->

`same as` checks if a variable is the same as another variable. This is the equivalent to == in Lua:

```twig
{% if foo.attribute is same as(false) %}
    the foo attribute really is the 'false' PHP value
{% endif %}
```

<!-- {% endraw %} -->