Filter `default`
================

<!-- {% raw %} -->

Filter `default(default)`:
* `default`: The default value
* `boolean`: Cast the value to boolean (default: `false`) 

The `default` filter returns the passed default value if the value is undefined or empty, otherwise the value of the variable:

```twig
{{ var|default('var is not defined') }}

{{ var.foo|default('foo item on var is not defined') }}

{{ var['foo']|default('foo item on var is not defined') }}
```

If you want to use default with variables that evaluate to false you have to set the second parameter to `true`:

```twig
{{ ''|default('passed var is empty')  }}
```

<!-- {% endraw %} -->