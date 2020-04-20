Filter `raw`
============

<!-- {% raw %} -->

The `raw` filter marks the value as being "safe", which means that in an environment with automatic escaping enabled 
this variable will not be escaped if raw is the last filter applied to it:

```twig
{% autoescape %}
    {{ var|raw }} {# var won't be escaped #}
{% endautoescape %}
```

**Note.** Be careful when using the `raw` filter inside expressions:
```twig
{% autoescape %}
    {% set hello = '<strong>Hello</strong>' %}
    {% set hola = '<strong>Hola</strong>' %}

    {{ false ? '<strong>Hola</strong>' : hello|raw }}
    does not render the same as
    {{ false ? hola : hello|raw }}
    but renders the same as
    {{ (false ? hola : hello)|raw }}
{% endautoescape %}
```
The first ternary statement is not escaped: `hello` is marked as being safe and Aspect does not escape static values (see [escape](./escape.md)). 
In the second ternary statement, even if `hello` is marked as safe, `hola` remains unsafe and so is the whole expression. 
The third ternary statement is marked as safe and the result is not escaped.

<!-- {% endraw %} -->