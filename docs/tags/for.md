Tag `for`
=========

[[_TOC_]]

Loop over each item in a sequence. 
For example, to display a list of users provided in a variable called `users`:

```twig
<h1>Members</h1>
<ul>
    {% for user in users %}
        <li>{{ user.username|e }}</li>
    {% endfor %}
</ul>
```

The else Clause
---------------

If no iteration took place because the sequence was empty, you can render a replacement block by using `else`:

```twig
<ul>
    {% for user in users %}
        <li>{{ user.username|e }}</li>
    {% else %}
        <li><em>no user found</em></li>
    {% endfor %}
</ul>
```

Iterating over Keys
-------------------

By default, a loop iterates over the values of the sequence. You can iterate on keys by using the `keys` filter:

```twig
<h1>Members</h1>
<ul>
    {% for key in users|keys %}
        <li>{{ key }}</li>
    {% endfor %}
</ul>
```

Iterating over Keys and Values
------------------------------

You can also access both keys and values:

```twig
<h1>Members</h1>
<ul>
    {% for key, user in users %}
        <li>{{ key }}: {{ user.username|e }}</li>
    {% endfor %}
</ul>
```

The loop variable
-----------------

Inside of a `for` loop block you can access some special variables:

| Variable          | Description               |
|-------------------|---------------------------|
| loop.index        | The current iteration of the loop. (1 indexed) |
| loop.index0       | The current iteration of the loop. (0 indexed) |
| loop.revindex     | The number of iterations from the end of the loop (1 indexed) |
| loop.revindex0    | The number of iterations from the end of the loop (0 indexed) |
| loop.first        | True if first iteration |
| loop.last         | True if last iteration |
| loop.length       | The number of items in the sequence |
| loop.parent       | The parent context |
| loop.prev_item    |  |

Behavior
--------

| Value                    | action               |
|--------------------------|----------------------|
| empty string             | not iterate          |
| numeric zero             | not iterate          |
| empty table              | not iterate          |
| nil/null                 | not iterate          |
| userdata                 | not iterate          |
| table with `__ipairs`    | iterate `__ipairs()` |
| table with `__pairs`     | iterate `__pairs()`  |
| table                    | iterate              |
