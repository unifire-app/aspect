Function `range`
================

<!-- {% raw %} -->

Returns a list containing an arithmetic progression of integers:

```twig
{% for i in range(0, 3) %}
    {{ i }},
{% endfor %}

{# outputs 0, 1, 2, 3, #}
```

When step is given (as the third parameter), it specifies the increment (or decrement for negative values):

```twig
{% for i in range(0, 6, 2) %}
    {{ i }},
{% endfor %}

{# outputs 0, 2, 4, 6, #}
```

**Note** that if the start is greater than the end, range assumes a step of -1:
```twig
{% for i in range(3, 0) %}
    {{ i }},
{% endfor %}

{# outputs 3, 2, 1, 0, #}
```

The `range` function returns the table with iterator (`__pairs`).

<!-- {% endraw %} -->