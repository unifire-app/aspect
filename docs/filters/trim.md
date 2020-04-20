Filter `trim`
=============

<!-- {% raw %} -->

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