Tag `if`
=======

<!-- {% raw %} -->

In the simplest form you can use it to test if an expression evaluates to `true`:

```twig
{% if online == false %}
    <p>Our website is in maintenance mode. Please, come back later.</p>
{% endif %}
```

You can also test if an array is not empty:

```twig
{% if users %}
    <ul>
        {% for user in users %}
            <li>{{ user.username|e }}</li>
        {% endfor %}
    </ul>
{% endif %}
```

**NOTE** If you want to test if the variable is defined, use `if users is defined` instead.

You can also use `not` to check for values that evaluate to false:

```twig
{% if not user.subscribed %}
    <p>You are not subscribed to our mailing list.</p>
{% endif %}
```

For multiple conditions, and and or can be used:

```twig
{% if temperature > 18 and temperature < 27 %}
    <p>It's a nice day for a walk in the park.</p>
{% endif %}
```

For multiple branches `elseif` (or `elif`) and `else` can be used. You can use more complex `expressions` there too:

```twig
{% if product.stock > 10 %}
   Available
{% elseif product.stock > 0 %}
   Only {{ product.stock }} left!
{% else %}
   Sold-out!
{% endif %}
```

The rules to determine if an expression is true or false are (edge cases):

| Value                    | Boolean evaluation |
|--------------------------|--------------------|
| empty string             | false              |
| numeric zero             | false              |
| whitespace-only string   | true               |
| string "0" or '0'        | true               |
| empty table              | false              |
| nil                      | false              |
| non-empty table          | true               |
| table with `__toboolean` | `__toboolean()`    |
| cjson.null               | false              |
| cbson.null()             | false              |
| lyaml.null               | false              |
| yaml.null                | false              |
| ngx.null                 | false              |
| msgpack.null             | false              |

Function `__toboolean()` should be in the metatable. 

You can add your own [false-behaviour](./../api.md#condition-behaviour)

<!-- {% endraw %} -->