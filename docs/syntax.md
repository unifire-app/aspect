Syntax
======

[[_TOC_]]

Operators
---------

### Math operators

* `+`: Adds two numbers together (the operands are casted to numbers). {{ 1 + 1 }} is 2.
* `-`: Subtracts the second number from the first one. {{ 3 - 2 }} is 1.
* `/`: Divides two numbers. The returned value will be a floating point number. {{ 1 / 2 }} is {{ 0.5 }}.
* `%`: Calculates the remainder of an integer division. {{ 11 % 7 }} is 4.
* `//`: Divides two numbers and returns the floored integer result. {{ 20 // 7 }} is 2, {{ -20 // 7 }} is -3 (this is just syntactic sugar for the round filter).
* `*`: Multiplies the left operand with the right one. {{ 2 * 2 }} would return 4.
* `**`: Raises the left operand to the power of the right operand. {{ 2 ** 3 }} would return 8.

### Logic operators

* `and`: Returns true if the left and the right operands are both true.
* `or`: Returns true if the left or the right operand is true.
* `not`: Negates a statement.
* `(expr)`: Groups an expression.

### Comparisons operators

The following comparison operators are supported in any expression: `==`, `!=`, `<`, `>`, `>=`, and `<=`.

You can also check if a string `starts` with or `ends` with another string:

```twig
{% if 'Aspect' starts with 'A' %}
{% endif %}

{% if 'Aspect' ends with 't' %}
{% endif %}
```

### Containment Operator

The `in` operator performs containment test. It returns `true` if the left operand is contained in the right:

```twig
{# returns true #}

{{ 1 in [1, 2, 3] }}

{{ 'cd' in 'abcde' }}
```

To perform a negative test, use the `not in` operator:

```twig
{% if 1 not in [1, 2, 3] %}

{# is equivalent to #}
{% if not (1 in [1, 2, 3]) %}
```

### Test Operator

The `is` operator performs tests. Tests can be used to test a variable against a common expression. The right operand is name of the test:

```twig
{# find out if a variable is odd #}

{{ name is odd }}
```

Tests can be negated by using the `is not` operator:

```twig
{% if name is not odd %} {% endif %}
{# is equivalent to #}
{% if not (name is odd) %} {% endif %}
```

### Other Operators

The following operators don't fit into any of the other categories:

* `|`: Applies a filter.
* `~`: Converts all operands into strings and concatenates them. `{{ "Hello " ~ what ~ "!" }}` would return (assuming `what` is 'world') Hello world!.
* `.`, `[]`: Gets an attribute of a variable.
* `?:`: The ternary operator:
  ```twig
  {{ foo ? 'yes' : 'no' }}
  {{ foo ?: 'no' }} is the same as {{ foo ? foo : 'no' }}
  {{ foo ? 'yes' }} is the same as {{ foo ? 'yes' : '' }}
  ```
* `??`: The null-coalescing operator:
  ```twig
  {# returns the value of foo if it is defined and not null, 'no' otherwise #}
  {{ foo ?? 'no' }}
  ```
  
### Precedence

Operator precedence, from the higher to the lower priority:

* `.`, `[]`
* `(expr)`
* `|`
* `**`
* `not`, `-` (unary)
* `is`, `is not`, `in`, `not in`
* `*`, `/`, `//`, `%`
* `+`, `-`
* `~`
* `?:`, `??`
* `<`, `>`, `<=`, `>=`, `!=`, `==`
* `and`
* `or`
