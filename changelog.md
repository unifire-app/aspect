ChangeLog
=========

Develop
-------

none

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