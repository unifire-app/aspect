Filter `split`
==============

<!-- {% raw %} -->

Filter `split(delimiter, limit)`:
* `delimiter`: The delimiter
* `limit`: The limit argument

---

The `split` filter splits a string by the given delimiter and returns a list of strings:

```twig
{% set foo = "one,two,three"|split(',') %}
{# foo contains ['one', 'two', 'three'] #}
```

If `limit` is set, the returned array will contain a maximum of limit elements with the last element containing the rest of string;

```twig
{% set foo = "one,two,three,four,five"|split(',', 3) %}
{# foo contains ['one', 'two', 'three,four,five'] #}
```

<!-- {% endraw %} -->