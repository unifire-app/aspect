Test `empty`
============

`empty` checks if a variable is an empty string, an empty array, an empty hash, 
exactly false, exactly null or numeric zero.

For objects that has the __len meta method, empty will check the return value of the __len() method.

For objects that has the __toboolean meta method (and not __len), empty will check the return value of the __toboolean() meta method.

```twig
{% if foo is empty %}
    ...
{% endif %}
```