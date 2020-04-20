Filter `length`
================

<!-- {% raw %} -->

The `length` filter returns the number of items of a sequence or mapping, or the length of a string.

```twig
{% if users|length > 10 %}
    ...
{% endif %}
```

`length` behavior:

* string ([luautf8](https://luarocks.org/modules/dannote/utf8) package installed): count of characters 
* string (without [luautf8](https://luarocks.org/modules/dannote/utf8) package): count of bytes
* table with `__len` meta function: result of `table:__len()`
* table with `__pairs` meta function: count of elements `table:__pairs()`
* table: count of elements 
* other: always `0`

<!-- {% endraw %} -->