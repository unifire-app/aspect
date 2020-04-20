Tag `verbatim`
==============

<!-- {% raw %} -->

The `verbatim`  tag marks sections as being raw text that should not be parsed. 
For example to put Aspect syntax as example into a template you can use this snippet:

```twig
{% verbatim %}
    <ul>
    {% for item in seq %}
        <li>{{ item }}</li>
    {% endfor %}
    </ul>
{% endverbatim %}
```

<!-- {% endraw %} -->