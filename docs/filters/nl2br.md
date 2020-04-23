[Aspect](./../../readme.md) › [Filters](./../filters.md) › nl2br
==============

<!-- {% raw %} -->

Filter `nl2br`:
* no args

---

The `nl2br` filter inserts HTML line breaks before all newlines in a string:

```twig
{{ "I like Aspect.\nYou will like it too."|nl2br }}
{# outputs

    I like Aspect.<br />
    You will like it too.

#}
```

<!-- {% endraw %} -->