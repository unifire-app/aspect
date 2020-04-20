Function `include`
==================

<!-- {% raw %} -->

The `include` function returns the rendered content of a template:

```twig
{{ include('template.html') }}
{{ include(some_var) }}
```

Included templates have access to the variables of the active context.

If you are using the filesystem loader, the templates are looked for in the paths defined by it.

The context is passed by default to the template but you can also pass additional variables:

```twig
{# template.html will have access to the variables from the current context and the additional ones provided #}
{{ include('template.html', {foo: 'bar'}) }}
```

You can disable access to the context by setting with_context to false:

```twig
{# only the foo variable will be accessible #}
{{ include('template.html', {foo: 'bar'}, with_context = false) }}
```

```twig
{# no variables will be accessible #}
{{ include('template.html', with_context = false) }}
```

When you set the ignore_missing flag, Twig will return an empty string if the template does not exist:

```twig
{{ include('sidebar.html', ignore_missing = true) }}
```

You can also provide a list of templates that are checked for existence before inclusion. 
The first template that exists will be rendered:

```twig
{{ include(['page_detailed.html', 'page.html']) }}
```

If `ignore_missing` is set, it will fall back to rendering nothing if none of the templates exist, otherwise it will throw an exception.

<!-- {% endraw %} -->