Tag `autoescape`
================

<!-- {% raw %} -->

Whether automatic escaping is enabled or not, you can mark a section of a template 
to be escaped or not by using the `autoescape` tag:

```twig
{% autoescape %}
    Everything will be automatically escaped in this block
    using the HTML strategy
{% endautoescape %}

{% autoescape false %}
    Everything will be outputted as is in this block
{% endautoescape %}
```

When automatic escaping is enabled everything is escaped by default except for values explicitly marked as safe. 
Those can be marked in the template by using the [raw](../filters/raw.md) filter:

```twig
{% autoescape %}
    {{ safe_value|raw }}
{% endautoescape %}
```

<!-- {% endraw %} -->