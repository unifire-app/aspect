---
layout: page
title: Command Line
---

<!-- {% raw %} -->

Usage:  `aspect [options] data_file template_name`.  data_file should be JSON.

Result outputs to STDOUT. Logs and errors output to STDERR.

See `aspect --help` for more information.

Examples
-------

Render JSON file to STDOUT or file:
```bash
aspect path/to/fixture.json path/to/template.tmpl
aspect path/to/fixture.json path/to/template.tmpl >path/to/result.txt
```

Render data from STDIN (using `-`):

```bash
aspect - path/to/template.tmpl
```

Read template from STDIN (using -):
```bash
aspect path/to/fixture.json -
```

Lint the template:
```bash
aspect --lint path/to/template.tmpl
```

<!-- {% endraw %} -->