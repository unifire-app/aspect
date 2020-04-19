package = "aspect"
version = "1.12-0"
source = {
    url = "https://github.com/unifire-app/aspect/archive/1.12.zip",
    dir = "aspect-1.12"
}
description = {
    summary = "Aspect is a powerful templating engine for Lua and OpenResty with syntax Twig/Django/Jinja/Liquid.",
    homepage = "https://github.com/unifire-app/aspect",
    license = "BSD-3-Clause",
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["aspect"]             = "src/aspect/init.lua",
        ["aspect.config"]      = "src/aspect/config.lua",
        ["aspect.template"]    = "src/aspect/template.lua",
        ["aspect.output"]      = "src/aspect/output.lua",
        ["aspect.err"]         = "src/aspect/err.lua",

        ["aspect.tags"]        = "src/aspect/tags.lua",
        ["aspect.filters"]     = "src/aspect/filters.lua",
        ["aspect.funcs"]       = "src/aspect/funcs.lua",
        ["aspect.tests"]       = "src/aspect/tests.lua",

        ["aspect.compiler"]    = "src/aspect/compiler.lua",
        ["aspect.tokenizer"]   = "src/aspect/tokenizer.lua",
        ["aspect.ast"]         = "src/aspect/ast.lua",
        ["aspect.ast.ops"]     = "src/aspect/ast/ops.lua",

        ["aspect.utils"]       = "src/aspect/utils.lua",
        ["aspect.utils.batch"] = "src/aspect/utils/batch.lua",
        ["aspect.utils.range"] = "src/aspect/utils/range.lua",
        ["aspect.utils.date"]  = "src/aspect/utils/date.lua",

        ["aspect.loader.array"]      = "src/aspect/loader/array.lua",
        ["aspect.loader.filesystem"] = "src/aspect/loader/filesystem.lua",
        ["aspect.loader.resty"]      = "src/aspect/loader/resty.lua",

        ["aspect.cli"]          = "src/aspect/cli.lua",
    },
    install = {
        bin = {
            ['aspect'] = 'bin/aspect'
        }
    }
}
