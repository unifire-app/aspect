---
layout: page
title: Filters › last
---

[← filters](./../filters.md)

<!-- {% raw %} -->

Filter: `last`:
* no args

---

The last filter returns the last "element" of a sequence, a mapping, or a string:

```twig
{{ [1, 2, 3, 4]|last }}
{# outputs 4 #}

{{ { a: 1, b: 2, c: 3, d: 4 }|last }}
{# outputs 4 #}

{{ '1234'|last }}
{# outputs 4 #}
```

**Note.** If the object has the `__pairs` function, then it will be used to search for the last element.

<!-- {% endraw %} -->