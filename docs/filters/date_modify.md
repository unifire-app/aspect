Filter date_modify
==================

The `date_modify` filter modifies a date with a given modifier values:

```twig
{{ post.published_at|date_modify({days: -2})|date("m/d/Y") }}
```

Positive number increase value, negative value decrease value.

Possible modifiers:

| keys | action |
|------|--------|
| days | incr or decr days |
| hours  | incr or decr hours  |
| minutes  | incr or decr minutes  |
| seconds | incr or decr seconds |
| months  | incr or decr months  |
| years  | incr or decr years  |
