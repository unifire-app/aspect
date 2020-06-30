---
layout: page
title: Filters › truncate
---

[← filters](./../filters.md)

<!-- {% raw %} -->

Filter `truncate(length, ending)`:
* `length`: This determines how many characters to truncate to.
* `ending`: This is a text string that replaces the truncated text. Its length is NOT included in the truncation length setting.

---

This truncates a string to a character length. 
As an optional second parameter, you can specify a string of text to display at the end if the sting was truncated. 

**Note** `truncate` filter works only with ascii symbols. 
For UTF8 string use `utf.truncate` filter (requires [utf8 module](./../api.md#configure-utf8))

```twig
{{ long_title }}
{{ long_title|truncate }}
{{ long_title|truncate(30) }}
{{ long_title|truncate(30, "") }}
{{ long_title|truncate(30, "---") }}
```

<!-- {% endraw %} -->