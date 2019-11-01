package = "aspect"
version = "git-1"
source = {
    url = "https://github.com/unifire-app/aspect/-/archive/master/aspect-master.zip"
}
description = {
    summary = "Aspect is a compiling (HTML) templating engine for Lua and OpenResty.",
    detailed = [[
        * Syntax: Twig and Jija2
        * OpenResty compatible
        *
    ]],
    license = "Apache 2.0",
}
dependencies = {
    "penlight",
    "date"
}
build = {
    type = "builtin",
    modules = {
        ["aspect.config"]  = "src/aspect/config.lua",
        ["aspect.template"]  = "src/aspect/template.lua",
        ["aspect.compiler"]  = "src/aspect/compiler.lua",
        ["aspect.tags"]  = "src/aspect/tags.lua",
        ["aspect.err"]  = "src/aspect/err.lua",
        ["aspect.filters"]  = "src/aspect/filters.lua",
        ["aspect.funcs"]  = "src/aspect/funcs.lua",
        ["aspect.tests"]  = "src/aspect/tests.lua",
        ["aspect.tokenizer"]  = "src/aspect/tokenizer.lua",
        ["aspect.output"]  = "src/aspect/output.lua",
    }
}