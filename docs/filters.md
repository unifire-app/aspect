Filters
=======


abs
---

Filter `column(abs)`.

The `abs` filter returns the absolute value.

```twig
{# number = -5 #}

{{ number|abs }}

{# outputs 5 #}
```

columns
-------

Filter `column(name)`:
* `name`: The column name to extract

The `column` filter returns the values from a single column in the input array.

```twig
{% set items = [{ 'fruit' : 'apple'}, {'fruit' : 'orange' }] %}

{% set fruits = items|column('fruit') %}

{# fruits now contains ['apple', 'orange'] #}
```

escape
------

Filter `escape(strategy)`:
* `strategy`: The escaping strategy. By default is `html`.

The `escape` filter escapes a string using strategies that depend on the context.

By default, it uses the HTML escaping strategy:

```twig
<p>
    {{ user.username|escape }}
</p>
```

For convenience, the `e` filter is defined as an alias:

```twig
<p>
    {{ user.username|e }}
</p>
```

The escape filter can also be used in other contexts than HTML thanks to an optional 
argument which defines the escaping strategy to use:

```twig
{{ user.username|e }}
{# is equivalent to #}
{{ user.username|e('html') }}
```

And here is how to escape variables included in JavaScript code:

```twig
{{ user.username|escape('js') }}
{{ user.username|e('js') }}
```

The `escape` filter supports the following escaping strategies for HTML documents:

* `html`: escapes a string for the **HTML body** context.
* `js`: escapes a string for the **JavaScript** context.
* `url`: escapes a string for the **URI or parameter** contexts. 
   This should not be used to escape an entire URI; only a subcomponent being inserted.

Also you cat [add your custom escaper](./api.md#custom-escaper).
   
Built-in escapers cannot be overridden mainly because they should be considered 
as the final implementation and also for better performance.

default
-------

Filter `default(default)`:
* `default`: The default value 

The `default` filter returns the passed default value if the value is undefined or empty, otherwise the value of the variable:

```twig
{{ var|default('var is not defined') }}

{{ var.foo|default('foo item on var is not defined') }}

{{ var['foo']|default('foo item on var is not defined') }}

{{ ''|default('passed var is empty')  }}
```