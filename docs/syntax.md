Template Syntax
===============

<!-- {% raw %} -->

A template is a regular text file. 
It can generate any text-based format (HTML, XML, CSV, LaTeX, etc.). It doesn't have a specific extension, 
.html or .xml are just fine.

A template contains **variables** or **expressions**, which get replaced with values when the template is evaluated, 
and tags, which control the template's logic.

Below is a minimal template that illustrates a few basics. We will cover further details later on:

```twig
<!DOCTYPE html>
<html>
    <head>
        <title>{{ page.title }}</title>
    </head>
    <body>
        <ul id="navigation">
        {% for item in navigation %}
            <li><a href="{{ item.href }}">{{ item.caption }}</a></li>
        {% endfor %}
        </ul>

        <h1>My Webpage</h1>
        {{ page.body }}
    </body>
</html>
```
There are two kinds of delimiters: `{% ... %}` and `{{ ... }}`. 
The first one is used to execute statements such as for-loops, the latter outputs the result of an expression.

Table Of Content
----------------

- [Variables](#variables)
  - [Global Variables](#global-variables)
  - [Setting Variables](#setting-variables)
- [Filters](#filters)
- [Functions](#functions)
- [Named Arguments](#named-arguments)
- [Control Structure](#control-structure)
- [Comments](#comments)
- [Template Inheritance](#template-inheritance)
- [Macros](#macros)
- [Expressions](#expressions)
  - [Literals](#literals)
- [Operators](#operators)
  - [Math Operators](#math-operators)
  - [Logic Operators](#logic-operators)
  - [Comparisons Operators](#comparisons-operators)
  - [Containment Operators](#containment-operator)
  - [Test Operators](#test-operator)
  - [Other Operators](#other-operators)
  - [Operator Precedence](#operator-precedence)
- [Whitespace Control](#whitespace-control)
- [HTML Escaping](#html-escaping)
  - [Manual Escaping](#working-with-manual-escaping)
  - [Automatic Escaping](#working-with-automatic-escaping)

Variables
---------

The application passes variables to the templates for manipulation in the template. 
Variables may have attributes or elements you can access, too. 
The visual representation of a variable depends heavily on the application providing it.

Use a dot (.) to access attributes of a variable:

```twig
{{ foo.bar }}
```

**Note.** It's important to know that the curly braces are _not_ part of the variable but the print statement. 
When accessing variables inside tags, don't put the braces around them.

If a variable or attribute does not exist, you will receive a null value.

### Global Variables

The following variables are always available in templates:

* `_self`: references the current template name;
* `_context`: references the current context;
* `_charset`: references the current charset.

### Setting Variables

You can assign values to variables inside code blocks. Assignments use the [set](./tags/set.md) tag:
```twig
{% set foo = 'foo' %}
{% set foo = [1, 2] %}
{% set foo = {'foo': 'bar'} %}
```

Filters
-------

Variables can be modified by **filters**. 
Filters are separated from the variable by a pipe symbol (`|`). Multiple filters can be chained. The output of one filter is applied to the next.

The following example removes all HTML tags from the `name` and title-cases it:

```twig
{{ name|striptags|title }}
```

Filters that accept arguments have parentheses around the arguments. This example joins the elements of a list by commas:

```twig
{{ list|join(', ') }}
```

To apply a filter on a section of code, wrap it with the [apply](./tags/apply.md) tag:

```twig
{% apply upper %}
    This text becomes uppercase
{% endapply %}
```
Go to the [filters](../readme.md#filters) list to learn more about built-in filters.

Functions
---------

Functions can be called to generate content. Functions are called by their name followed by parentheses (`()`) and may have arguments.

For instance, the `range` function returns a list containing an arithmetic progression of integers:

```twig
{% for i in range(0, 3) %}
    {{ i }},
{% endfor %}
```

Go to the [functions](../readme.md#functions) list to learn more about the built-in functions.

Named Arguments
---------------

```twig
{% for i in range(low=1, high=10, step=2) %}
    {{ i }},
{% endfor %}
```

Using named arguments makes your templates more explicit about the meaning of the values you pass as arguments:

```twig
{{ names|join(', ', ' and ') }}

{# versus #}

{{ names|join(last_delim=' and ', delim=', ') }}
```

Named arguments also allow you to skip some arguments for which you don't want to change the default value:

```twig
{{ names|join(null, ' and ') }}

{{ names|join(last_delim=' and ')}}
```

You can also use both positional and named arguments in one call, 
in which case positional arguments must always come before named arguments:

```twig
{{ names|join(', ', last_delim = ' and ') }}
```

**Note.** 
Each function and filter documentation page has a section where the names of all arguments are listed when supported.

Control Structure
-----------------

A control structure refers to all those things that control the flow of a program - conditionals (i.e. `if/elseif/else`), 
`for`-loops, as well as things like blocks. Control structures appear inside `{% ... %}` blocks.

For example, to display a list of users provided in a variable called `users`, use the [for](./tags/for.md) tag:

```twig
<h1>Members</h1>
<ul>
    {% for user in users %}
        <li>{{ user.username|e }}</li>
    {% endfor %}
</ul>
```

The [if](./tags/if.md) tag can be used to test an expression:

```twig
{% if users|length > 0 %}
    <ul>
        {% for user in users %}
            <li>{{ user.username|e }}</li>
        {% endfor %}
    </ul>
{% endif %}
```

Go to the [tags](../readme.md#tags) list to learn more about the built-in tags.

Comments
--------

To comment-out part of a line in a template, use the comment syntax `{# ... #}`. 
This is useful for debugging or to add information for other template designers or yourself:

```twig
{# note: disabled template because we no longer use this
    {% for user in users %}
        ...
    {% endfor %}
#}
```

Template Inheritance
--------------------

Template inheritance allows you to build a base "skeleton" template that contains all the common elements 
of your site and defines **blocks** that child templates can override.

It's easier to understand the concept by starting with an example.

Let's define a base template, `base.html`, which defines an HTML skeleton document that might be used for a two-column page:

```twig
<!DOCTYPE html>
<html>
    <head>
        {% block head %}
            <link rel="stylesheet" href="style.css" />
            <title>{% block title %}{% endblock %} - My Webpage</title>
        {% endblock %}
    </head>
    <body>
        <div id="content">{% block content %}{% endblock %}</div>
        <div id="footer">
            {% block footer %}
                &copy; Copyright 2011 by <a href="http://domain.invalid/">you</a>.
            {% endblock %}
        </div>
    </body>
</html>
```

In this example, the [block](./tags/extends.md#block) tags define four blocks that child templates can fill in. 
All the `block` tag does is to tell the template engine that a child template may override those portions of the template.

A child template might look like this:

```twig
{% extends "base.html" %}

{% block title %}Index{% endblock %}
{% block head %}
    {{ parent() }}
    <style type="text/css">
        .important { color: #336699; }
    </style>
{% endblock %}
{% block content %}
    <h1>Index</h1>
    <p class="important">
        Welcome to my awesome homepage.
    </p>
{% endblock %}
```

The [extends](./tags/extends.md) tag is the key here. It tells the template engine that this template "extends" another template. 
When the template system evaluates this template, first it locates the parent. 
The extends tag should be the first tag in the template.

Note that since the child template doesn't define the `footer` block, the value from the parent template is used instead.

It's possible to render the contents of the parent block by using the [parent](./tags/extends.md#parent) function. This gives back the results of the parent block:

```twig
{% block sidebar %}
    <h3>Table Of Contents</h3>
    ...
    {{ parent() }}
{% endblock %}
```

**Note.** The documentation page for the [extends](./tags/extends.md) tag describes more advanced features like block nesting, scope, dynamic inheritance, and conditional inheritance.

**Note.** Aspect also supports multiple inheritance via "horizontal reuse" with the help of the [use](./tags/extends.md#use) tag.

Macros
------

Macros are comparable with functions in regular programming languages. 
They are useful to reuse HTML fragments to not repeat yourself. 
They are described in the [macro](./tags/macro.md) tag documentation.

Expressions
-----------

Aspect allows expressions everywhere.

### Literals

The following literals exist:

* `"Hello World"`: Everything between two double or single quotes is a string. 
  They are useful whenever you need a string in the template (for example as arguments to function calls, 
  filters or just to extend or include a template). A string can contain a delimiter 
  if it is preceded by a backslash (`\`) -- like in `'It\'s good'`. 
* `42` / `42.23`: Integers and floating point numbers are created by writing the number down. 
  If a dot is present the number is a float, otherwise an integer.
* `["foo", "bar"]`: Arrays (indexed tables) are defined by a sequence of expressions separated by a comma (`,`) 
  and wrapped with squared brackets (`[]`).
* `{"foo": "bar"}`: Hashes (associative tables) are defined by a list of keys and values separated by a comma (`,`) 
  and wrapped with curly braces (`{}`):
  ```twig
  {# keys as string #}
  { 'foo': 'foo', 'bar': 'bar' }
  
  {# keys as names (equivalent to the previous hash) #}
  { foo: 'foo', bar: 'bar' }
  
  {# keys as integer #}
  { 2: 'foo', 4: 'bar' }
  
  {# keys as expressions (the expression must be enclosed into parentheses) #}
  {% set foo = 'foo' %}
  { (foo): 'foo', (1 + 1): 'bar', (foo ~ 'b'): 'baz' }
  ```
* `true` / `false`: true represents the true value, false represents the false value.
* `null` / `nil`: null represents no specific value. This is the value returned when a variable does not exist. 
  `nil` is an alias for `null`.
  
Arrays and hashes can be nested:

```twig
{% set foo = [1, {"foo": "bar"}] %}
```

Operators
---------

### Math operators

* `+`: Adds two numbers together (the operands are casted to numbers). `{{ 1 + 1 }}` is 2.
* `-`: Subtracts the second number from the first one. `{{ 3 - 2 }}` is 1.
* `/`: Divides two numbers. The returned value will be a floating point number. `{{ 1 / 2 }}` is 0.5.
* `%`: Calculates the remainder of an integer division. `{{ 11 % 7 }}` is 4.
* `//`: Divides two numbers and returns the floored integer result. `{{ 20 // 7 }}` is 2, `{{ -20 // 7 }}` is -3 (this is just syntactic sugar for the round filter).
* `*`: Multiplies the left operand with the right one. `{{ 2 * 2 }}` would return 4.
* `**`: Raises the left operand to the power of the right operand. `{{ 2 ** 3 }}` would return 8.

### Logic operators

* `and`: Returns true if the left and the right operands are both true.
* `or`: Returns true if the left or the right operand is true.
* `not`: Negates a statement.
* `(expr)`: Groups an expression.

### Comparisons operators

The following comparison operators are supported in any expression: `==`, `!=`, `<`, `>`, `>=`, and `<=`.

**Note.** Aspect automatically cast values to numbers then `<`, `>`, `>=`, and `<=` used. 
But NOT cast to anything with `==` and `!=`, i. g. `"0" == 0` is `false`.

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
  
### Operator precedence

Operator precedence, from the higher to the lower priority:

1. `.`, `[]` (any)
2. `(expr)` (any)
3. `|` (any)
4. `**` (number)
5. `not` (boolean), `-` (number)
6. `is`, `is not`, `in`, `not in` (boolean)
7. `*`, `/`, `//`, `%` (number)
8. `+`, `-` (number)
9. `~` (string)
10. `<`, `>`, `<=`, `>=`, `!=`, `==` (boolean)
11. `?:`, `??` (any)
12. `? ... : ...` (any)
13. `and` (boolean)
14. `or` (boolean)


Whitespace Control
------------------

Whitespace is not further modified by the template engine, so each whitespace (spaces, tabs, newlines etc.) is returned unchanged.

You can also control whitespace on a per tag level. 
By using the whitespace control modifiers on your tags, you can trim leading and or trailing whitespace.

Aspect supports two modifiers:

* Whitespace trimming via the - modifier: Removes all whitespace (including newlines);
* Line whitespace trimming via the ~ modifier: Removes all whitespace (excluding newlines). 

The modifiers can be used on either side of the tags like in `{%-` or `-%}` and they consume all whitespace for that side of the tag. 
It is possible to use the modifiers on one side of a tag or on both sides:

```twig
{% set value = 'no spaces' %}
{#- No leading/trailing whitespace -#}
{%- if true -%}
    {{- value -}}
{%- endif -%}
{# output 'no spaces' #}

<li>
    {{ value }}    </li>
{# outputs '<li>\n    no spaces    </li>' #}

<li>
    {{- value }}    </li>
{# outputs '<li>no spaces    </li>' #}

<li>
    {{~ value }}    </li>
{# outputs '<li>\nno spaces    </li>' #}
```

HTML Escaping
-------------

When generating HTML from templates, there’s always a risk that a variable will include characters that affect the resulting HTML. 
There are two approaches: manually escaping each variable or automatically escaping everything by default.

Aspect supports both, automatic escaping is enabled by default.

The automatic escaping strategy can be configured via the [autoescape](./api.md#options) option.

## Working with Manual Escaping

If manual escaping is enabled, it is **your** responsibility to escape variables if needed. 
What to escape? Any variable that comes from an untrusted source.

Escaping works by using the [escape](./filters/escape.md) or `e` filter:

```twig
{{ user.username|e }}
```

By default, the [escape](./filters/escape.md) filter uses the html strategy, 
but depending on the escaping context, you might want to explicitly use an other strategy:

```twig
{{ user.username|e('html') }}
{{ user.username|e('js') }}
{{ user.username|e('url') }}
```

## Working with Automatic Escaping

Whether automatic escaping is enabled or not, you can mark a section of a template to be escaped 
or not by using the [autoescape](./tags/autoescape.md) tag:

```twig
{% autoescape %}
    Everything will be automatically escaped in this block (using the HTML strategy)
{% endautoescape %}
```

Currently auto-escaping uses only the html escaping strategy. 

<!-- {% endraw %} -->