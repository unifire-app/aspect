---
layout: page
title: Tags › apply
---

[← tags](./../tags.md)

<!-- {% raw %} -->

The `apply` tag allows you to apply Aspect filters on a block of template data:

```twig
{% apply upper %}
    This text becomes uppercase
{% endapply %}

{# outputs "THIS TEXT BECOMES UPPERCASE" #}
```

You can also chain filters and pass arguments to them:

```twig
{% apply lower|escape('html') %}
    <strong>SOME TEXT</strong>
{% endapply %}

{# outputs "&lt;strong&gt;some text&lt;/strong&gt;" #}
```

**NOTE**: The filter buffers the data. With a large amount of data processed by the filter, a large amount of RAM will be used.

<!-- {% endraw %} -->