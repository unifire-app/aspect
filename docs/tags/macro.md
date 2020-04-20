Macro
=====

<!-- {% raw %} -->

Macros are comparable with functions in regular programming languages. 
They are useful to reuse template fragments to not repeat yourself.

Macros are defined in regular templates.

Imagine having a generic helper template that define how to render HTML forms via macros (called `forms.html`):

```twig
{% macro input(name, value, type = "text", size = 20) %}
    <input type="{{ type }}" name="{{ name }}" value="{{ value|e }}" size="{{ size }}" />
{% endmacro %}

{% macro textarea(name, value, rows = 10, cols = 40) %}
    <textarea name="{{ name }}" rows="{{ rows }}" cols="{{ cols }}">{{ value|e }}</textarea>
{% endmacro %}
```

Each macro argument can have a default value (here text is the default value for type if not provided in the call).

Macros differ from native PHP functions in a few ways:

* Arguments of a macro are always optional.
* If extra positional arguments are passed to a macro, they end up in the special `_context` variable as a list of values.

Macros don't have access to the current template variables.

Importing Macros
----------------

There are two ways to import macros. 
You can import the complete template containing the macros into a local variable (via the `import` tag) 
or only import specific macros from the template (via the `from` tag).

To `import` all macros from a template into a local variable, use the `import` tag:

```twig
{% import "forms.html" as forms %}
```

The above import call imports the `forms.html` file (which can contain only macros, or a template and some macros), 
and import the macros as items of the `forms` local variable.

The macros can then be called at will in the _current_ template:

```twig
<p>{{ forms.input('username') }}</p>
<p>{{ forms.input('password', null, 'password') }}</p>
```

Alternatively you can import names from the template into the current namespace via the `from` tag:

```twig
{% from 'forms.html' import input as input_field, textarea %}

<p>{{ input_field('password', '', 'password') }}</p>
<p>{{ textarea('comment') }}</p>
```

When macro usages and definitions are in the same template, 
you don't need to import the macros as they are automatically available under the special `_self` variable:

```twig
<p>{{ _self.input('password', '', 'password') }}</p>

{% macro input(name, value, type = "text", size = 20) %}
    <input type="{{ type }}" name="{{ name }}" value="{{ value|e }}" size="{{ size }}" />
{% endmacro %}
```

<!-- {% endraw %} -->