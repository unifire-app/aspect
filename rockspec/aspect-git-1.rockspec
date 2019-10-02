package = "aspect"
version = "git-1"
source = {
    url = "https://github.com/unifire-app/aspect/-/archive/master/aspect-master.zip"
}
description = {
    summary = "Great template for lua",
    description = [[
        * Syntax: Twig and Jija2
        * OpenResty compatible
        *
    ]],
    license = "Apache 2.0",
}
dependencies = {
    "penlight",
}
build = {
    type = "builtin",
    modules = {
        ["aspect.template"]  = "src/aspect/template.lua",
        ["aspect.compiler"]  = "src/aspect/compiler.lua",
        ["aspect.err"]  = "src/aspect/err.lua",
        ["aspect.filters"]  = "src/aspect/filters.lua",
        ["aspect.lexer"]  = "src/aspect/lexer.lua",
        ["aspect.render"]  = "src/aspect/render.lua",
        ["aspect.tokenizer"]  = "src/aspect/tokenizer.lua",
    }
}