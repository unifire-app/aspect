Function `date`
===============

<!-- {% raw %} -->

Converts an argument to a date to allow date comparison:

```twig
{% if date(user.created_at) < date({days: -2}) %}
    {# do something #}
{% endif %}
```

The argument must be in one supported [parsable date and time formats](../filters/date.md#parsing).
or [date and time interval](../filters/date_modify.md)

If no argument is passed, the function returns the current date:

```twig
{% if date(user.created_at) < date() %}
    {# always! #}
{% endif %}
```

<!-- {% endraw %} -->