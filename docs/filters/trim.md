[Aspect](./../../readme.md) › [Filters](./../filters.md) › trim
=============

<!-- {% raw %} -->

Filter `trim(character_mask, side)`:
* `character_mask`: The characters to strip.
* `side`: The default is to strip from the left and the right (both) sides, 
  but left and right will strip from either the left side or right side only.

---

The `trim` filter strips whitespace (or other characters) from the beginning and end of a string:

```twig
{{ '  I like Aspect.  '|trim }}

{# outputs 'I like Aspect.' #}

{{ '  I like Aspect.'|trim('.') }}

{# outputs '  I like Aspect' #}

{{ '  I like Aspect.  '|trim(side='left') }}

{# outputs 'I like Aspect.  ' #}

{{ '  I like Aspect.  '|trim(' ', 'right') }}

{# outputs '  I like Aspect.' #}
```

<!-- {% endraw %} -->