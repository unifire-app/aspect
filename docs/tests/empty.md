Test `empty`
============

`empty` checks if a variable is an empty string, an empty array, an empty hash, 
exactly false, exactly null or numeric zero.

For objects that has the __count meta method, empty will check the return value of the __count() method.

For objects that has the __toboolean meta method (and not __count), empty will check the return value of the __toboolean() meta method.

```twig
{% if foo is empty %}
    ...
{% endif %}
```