package = "aspect"
version = "1.8-0"
source = {
    url = "https://github.com/unifire-app/aspect/archive/1.8.zip",
    dir = "aspect-1.8"
}
description = {
    summary = "Aspect is a compiling templating engine for Lua and OpenResty with syntax Twig/Jinja/Liquid.",
    detailed = [[
* Well known: The most popular Liquid-like syntax is used - Twig compatible and Jinja like.
* Fast: Aspect compiles templates down to plain optimized Lua code.
  Moreover, Lua code compiles into bytecode - the fastest representation of a template.
* Secure: Aspect has a sandbox mode to evaluate all template code.
  This allows Aspect to be used as a template language for applications where users may modify the template design.
* Flexible: Aspect is powered by a flexible lexer and parser.
  This allows the developer to define their own custom tags, filters, functions and operators, and to create their own DSL.
* Comfortable: Aspect allows you to process userdata data.
  More intuitive behavior with special values such as a empty string, number zero and so on.
* Memory-safe: The template is built in such a way as to save maximum memory when it is executed, even if the iterator provides a lot of data.
    ]],
    license = "BSD-3-Clause",
}
dependencies = {
    "penlight",
    "date",
    "lua-cjson"
}
build = {
    type = "builtin",
    modules = {
        ["aspect"]             = "src/aspect/init.lua",
        ["aspect.config"]      = "src/aspect/config.lua",
        ["aspect.template"]    = "src/aspect/template.lua",
        ["aspect.compiler"]    = "src/aspect/compiler.lua",
        ["aspect.output"]      = "src/aspect/output.lua",
        ["aspect.tags"]        = "src/aspect/tags.lua",
        ["aspect.err"]         = "src/aspect/err.lua",
        ["aspect.filters"]     = "src/aspect/filters.lua",
        ["aspect.funcs"]       = "src/aspect/funcs.lua",
        ["aspect.tests"]       = "src/aspect/tests.lua",
        ["aspect.tokenizer"]   = "src/aspect/tokenizer.lua",
        ["aspect.utils"]       = "src/aspect/utils.lua",
        ["aspect.ast"]         = "src/aspect/ast.lua",
        ["aspect.ast.ops"]     = "src/aspect/ast/ops.lua",
        ["aspect.utils.batch"] = "src/aspect/utils/batch.lua",
        ["aspect.utils.range"] = "src/aspect/utils/range.lua",
        ["aspect.loader.array"] = "src/aspect/loader/array.lua",
    }
}