Filter `batch`
==============

<!-- {% raw %} -->

Filter `batch(size)`:
* `size`: The size of the batch; fractional numbers will be rounded up

The `batch` filter "batches" items by returning a list of lists with the given number of items:

```twig
{% set items = ['a', 'b', 'c', 'd', 'e', 'f', 'g'] %}

<table>
{% for row in items|batch(3) %}
    <tr>
        {% for column in row %}
            <td>{{ column }}</td>
        {% endfor %}
    </tr>
{% endfor %}
</table>
```
The above example will be rendered as:

```html
<table>
    <tr>
        <td>a</td>
        <td>b</td>
        <td>c</td>
    </tr>
    <tr>
        <td>d</td>
        <td>e</td>
        <td>f</td>
    </tr>
    <tr>
        <td>g</td>
    </tr>
</table>
```

<!-- {% endraw %} -->