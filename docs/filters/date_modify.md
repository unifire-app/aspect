Filter date_modify
==================

<!-- {% raw %} -->

The `date_modify` filter modifies a date with a given modifier values:

```twig
{{ post.published_at|date_modify({days: -2})|date("m/d/Y") }}
```

Positive number increase value, negative value decrease value.

Possible modifiers:

| keys | action |
|------|--------|
| days, day | incr or decr days |
| hours, hour  | incr or decr hours  |
| minutes, minute, mins, min | incr or decr minutes  |
| seconds, second, secs, sec | incr or decr seconds |
| months, month  | incr or decr months  |
| years, year  | incr or decr years  |

<!-- {% endraw %} -->