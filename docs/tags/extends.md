`extends`
=========

<!-- {% raw %} -->

The `extends` tag can be used to extend a template from another one.

`block`
-------

## Parent Template

Let's define a base template, `base.html`, which defines a simple HTML skeleton document:

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

In this example, the [block](#block) tags define four blocks that child templates can fill in.

All the `block` tag does is to tell the template engine that a child template may override those portions of the template.

## Child Template

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
        Welcome on my awesome homepage.
    </p>
{% endblock %}
```

The `extends` tag is the key here. It tells the template engine that this template "extends" another template. 
When the template system evaluates this template, first it locates the parent. 
The extends tag should be the first tag in the template.

Note that since the child template doesn't define the `footer` block, the value from the parent template is used instead.

You can't define multiple `block` tags with the same name in the same template. 
This limitation exists because a block tag works in "both" directions. 
That is, a `block` tag doesn't just provide a hole to fill - it also defines the content that fills the hole in the `parent`. 
If there were two similarly-named `block` tags in a template, that template's parent wouldn't know which one of the blocks' content to use.

## Block function
When a template uses inheritance and if you want to print a block multiple times, use the `block` function:

```twig
<title>{% block title %}{% endblock %}</title>

<h1>{{ block('title') }}</h1>

{% block body %}{% endblock %}
```

The `block` function can also be used to display one block from another template:

```twig
	
{{ block("title", "common_blocks.html") }}
```

Use the `defined` test to check if a block exists in the context of the current template:

```twig
{% if block("footer") is defined %}
    ...
{% endif %}

{% if block("footer", "common_blocks.html") is defined %}
    ...
{% endif %}
```

## Named Block End-Tags

Aspect allows you to put the name of the block after the end tag for better readability 
(the name after the `endblock` word must match the block name):

```twig
{% block sidebar %}
    {% block inner_sidebar %}
        ...
    {% endblock inner_sidebar %}
{% endblock sidebar %}
```

## Block Nesting and Scope

Blocks can be nested for more complex layouts. Per default, blocks have access to variables from outer scopes:

```twig
{% for item in seq %}
    <li>{% block loop_item %}{{ item }}{% endblock %}</li>
{% endfor %}
```

`parent`
--------

When a template uses inheritance, it's possible to render the contents of the parent 
block when overriding a block by using the parent function:

```twig
{% block sidebar %}
    <h3>Table Of Contents</h3>
    ...
    {{ parent() }}
{% endblock %}
```
The parent() call will return the content of the sidebar block as defined in the base.html template.

How do blocks work?
-------------------

A block provides a way to change how a certain part of a template is rendered but it does not interfere in any way with the logic around it.

Let's take the following example to illustrate how a block works and more importantly, how it does not work:

```twig
{# base.tpl #}

{% for post in posts %}
    {% block post %}
        <h1>{{ post.title }}</h1>
        <p>{{ post.body }}</p>
    {% endblock %}
{% endfor %}
```

If you render this template, the result would be exactly the same with or without the `block` tag. 
The `block` inside the `for` loop is just a way to make it overridable by a child template:

```twig
{# child.tpl #}

{% extends "base.tpl" %}

{% block post %}
    <article>
        <header>{{ post.title }}</header>
        <section>{{ post.text }}</section>
    </article>
{% endblock %}
```

Now, when rendering the child template, the loop is going to use the block defined in the child template 
instead of the one defined in the base one; the executed template is then equivalent to the following one:

```twig
{% for post in posts %}
    <article>
        <header>{{ post.title }}</header>
        <section>{{ post.text }}</section>
    </article>
{% endfor %}
```

Let's take another example: a block included within an `if` statement:

```twig
{% if posts is empty %}
    {% block head %}
        {{ parent() }}

        <meta name="robots" content="noindex, follow">
    {% endblock head %}
{% endif %}
```

Contrary to what you might think, this template does not define a block conditionally; 
it just makes overridable by a child template the output of what will be rendered when the condition is `true`.

If you want the output to be displayed conditionally, use the following instead:

```twig
{% block head %}
    {{ parent() }}

    {% if posts is empty %}
        <meta name="robots" content="noindex, follow">
    {% endif %}
{% endblock head %}
```

Use
---

Template inheritance is one of the most powerful features of Aspect but it is limited to single inheritance; 
a template can only extend one other template. 
This limitation makes template inheritance simple to understand and easy to debug:

```twig
{% extends "base.html" %}

{% block title %}{% endblock %}
{% block content %}{% endblock %}
```

Horizontal reuse is a way to achieve the same goal as multiple inheritance, but without the associated complexity:

```twig
{% extends "base.html" %}

{% use "blocks.html" %}

{% block title %}{% endblock %}
{% block content %}{% endblock %}
```

The `use` statement tells Aspect to import the blocks defined in `blocks.html` into the current template 
(it's like `macros`, but for blocks):

```twig
{# blocks.html #}

{% block sidebar %}{% endblock %}
```

In this example, the `use` statement imports the `sidebar` block into the main template. 
The code is mostly equivalent to the following one (the imported blocks are not outputted automatically):

```twig
{% extends "base.html" %}

{% block sidebar %}{% endblock %}
{% block title %}{% endblock %}
{% block content %}{% endblock %}
```

<!-- {% endraw %} -->