---
layout: page
title: Development
---

Versioning
----------

Given a version number `X.Y`, increment the:
- `X` version when you make incompatible API changes
- `Y` version when you add functionality in a backwards compatible manner or bug fix. 

Convention
----------

- [EmmyLua](https://github.com/EmmyLua) with annotations is used for development.
- For unit test is used [busted](https://olivinelabs.com/busted/) 


Debug
-----

Dump (buggy) template:

```bash
bin/aspect --dump path/to/template.view
``` 