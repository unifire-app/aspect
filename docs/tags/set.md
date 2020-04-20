Tag `set`
=========

<!-- {% raw %} -->

Inside code blocks you can also assign values to variables.
Assignments use the `set` tag and can have multiple targets.

Here is how you can assign the `bar` value to the `foo` variable:
```twig
{% set foo = 'bar' %}
```

After the set call, the foo variable is available in the template like any other ones:

```twig
{# displays bar #}
{{ foo }}
```

The assigned value can be any valid [Aspect expression](../syntax.md#expression):

```twig
{% set foo = [1, 2] %}
{% set foo = {'foo': 'bar'} %}
{% set foo = 'foo' ~ 'bar' %}
```

The set tag can also be used to 'capture' chunks of text:

```twig
{% set foo %}
    <div id="pagination">
        ...
    </div>
{% endset %}
```

**NOTE** Note that loops are scoped in Aspect; therefore a variable declared inside a for loop is not accessible outside the loop itself:

```twig
{% for item in list %}
    {% set foo = item %}
{% endfor %}

{# foo is NOT available #}
```
If you want to access the variable, just declare it before the loop:
```twig
{% set foo = "" %}
{% for item in list %}
    {% set foo = item %}
{% endfor %}

{# foo is available #}
```

<!-- {% endraw %} -->