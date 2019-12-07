package = "aspect"
version = "git-1"
source = {
    url = "https://github.com/unifire-app/aspect/-/archive/master/aspect-master.zip"
}
description = {
    summary = "Aspect is a compiling templating engine for Lua and OpenResty with syntax Twig/Django/Jinja.",
    detailed = [[
* Popular Django syntax compatible with Twig2 and Jinja2
* Bytecode and lua code caching of compiled templates are available.
* Safe launch of templates in the sandbox.
* Automatic casting of data types when used.
* Designed for highload and big input and output data.
* Detailed error messages make it easy to debug templates.
* Easily extensible: add your own tags, filters, functions, handlers, operators.
* Intuitive behavior. For example, unlike lua, zero, an empty string, csjon.null, and so on, will be false in if-conditions. All of this is extensible.
* Custom behavior with userdata.
* Supports work with OpenResty.
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