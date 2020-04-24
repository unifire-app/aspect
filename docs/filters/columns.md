---
layout: page
title: Filters › columns
---

[← filters](./../filters.md)

<!-- {% raw %} -->

Filter `column(name)`:
* `name`: The column name to extract

---

The `column` filter returns the values from a single column in the input sequence.

```twig
{% set items = [{ 'fruit' : 'apple'}, {'fruit' : 'orange' }] %}

{% set fruits = items|column('fruit') %}

{# fruits now contains ['apple', 'orange'] #}
```

<!-- {% endraw %} -->