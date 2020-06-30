ChangeLog
=========

2.0
---

- Tag `with` now supports expressions.
- Extra build information
- Function `aspect.utils.dump` now works with nil
- Tokenizer with offset.
- Add compiler contexts. More information about the template.
- Improve template inheritance algorithm. The parent template is determined dynamically
- Add filter `truncate`
- UTF8 support:
  - add `require("aspect.config").utf` configuration
  - add filters `utf.lower`, `utf.upper`, `utf.truncate`
  - parsing localized dates
- Internal improvements.

Date:

- Move `aspect.utils.date` to `aspect.date`
- UTC time offset now in seconds (instead of minutes) 
- When formatting a date, if a time zone is not specified, then formatting will occur for the local time zone
- Add date localization.

1.14
----

- Add `aspect:eval(...)` method
- Add benchmark `benchmark/bench-01.lua`
- Improve compiler performance. 
- Update docs

1.13
----

- Add `apply` tag
- Run docs on github pages [aspect.unifire.app](https://aspect.unifire.app/)
- Reformat docs
- Add option `--dump` for CLI command (useful for debug)
- Dynamic keys now works (`a[b]` or `a['b' ~ c]`)

1.12
----

- Add date utils `aspect.utils.date`.
- Remove `date` dependency.
- More tests and docs.
- Bugfix.

1.11
----

- Improve tokenizer performance.  Remove `pl.lexer` from `aspect.tokenizer`.
- Improve filters performance. Remove `pl.tablex` and `pl.stringx` from `aspect.filters`.
- Remove `penlight` dependency.
- Remove `cjson` dependency. Add autodetect and configuration to `aspect.config`.
- Bugfix.

1.10
----

- Add CLI Aspect starter `aspect.cli`.
- Add console tool `bin/aspect`.
- More tests and docs.
- Bugfix.