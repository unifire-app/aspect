Filter `trim`
=============

The `trim` filter strips whitespace (or other characters) from the beginning and end of a string:

```twig
{{ '  I like Twig.  '|trim }}

{# outputs 'I like Twig.' #}

{{ '  I like Twig.'|trim('.') }}

{# outputs '  I like Twig' #}

{{ '  I like Twig.  '|trim(side='left') }}

{# outputs 'I like Twig.  ' #}

{{ '  I like Twig.  '|trim(' ', 'right') }}

{# outputs '  I like Twig.' #}
```