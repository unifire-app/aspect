---
layout: page
title: Filters › length
---

[← filters](./../filters.md)

<!-- {% raw %} -->

Filter: `length`:
* no args

---

The `length` filter returns the number of items of a sequence or mapping, or the length of a string.

```twig
{% if users|length > 10 %}
    ...
{% endif %}
```

`length` behavior:
 
* string: count of bytes (this is not count of symbols)
* table with `__len` meta function: result of `table:__len()`
* table with `__pairs` meta function: count of elements `table:__pairs()`
* table: count of elements 
* other: always `0`

<!-- {% endraw %} -->