local pcall = pcall
local require = require
local getmetatable = getmetatable

--- Internal configuration of
--- Aspect Template Engine. Be careful.
--- @class aspect.config
local config = {}

--- escape filter settings
config.escape = {
    pattern = "[}{\">/<'&]",
    replaces = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["/"] = "&#47;"
    }
}

--- condition aliases (also see bellow)
config.is_false = {
    [""] = true,
    [0] = true,
}

--- empty string variants (also see bellow)
config.is_empty_string = {
    [""] = true,
}

config.is_n = {
}

--- dynamically configure config.is_false and config.is_empty_string
do
    --- https://github.com/openresty/lua-nginx-module#core-constants
    local ngx = ngx or {}
    if ngx.null then
        config.is_false[ngx.null] = true
        config.is_empty_string[ngx.null] = true
    end

    --- https://luarocks.org/modules/openresty/lua-cjson
    local has_cjson, cjson = pcall(require, "cjson.safe")
    if has_cjson then
        config.is_false[cjson.null] = true
        config.is_empty_string[cjson.null] = true
    end

    --- https://github.com/isage/lua-cbson
    local has_cbson, cbson = pcall(require, "cbson")
    if has_cbson then
        config.is_false[getmetatable(cbson.null())] = true
        config.is_false[getmetatable(cbson.array())] = true
        config.is_empty_string[getmetatable(cbson.null())] = true
    end

    --- https://www.tarantool.io/ru/doc/1.10/reference/reference_lua/yaml/
    local has_yaml, yaml = pcall(require, "yaml")
    if has_yaml and yaml.NULL then
        config.is_false[yaml.NULL] = true
        config.is_empty_string[yaml.NULL] = true
    end

    --- https://github.com/gvvaughan/lyaml
    local has_lyaml, lyaml = pcall(require, "lyaml")
    if has_lyaml then
        config.is_false[lyaml.null] = true
        config.is_empty_string[lyaml.null] = true
    end

    --- https://www.tarantool.io/ru/doc/1.10/reference/reference_lua/msgpack/
    local has_msgpack, msgpack = pcall(require, "msgpack")
    if has_msgpack then
        config.is_false[msgpack.NULL] = true
        config.is_empty_string[msgpack.NULL] = true
    end

    config.is_n[getmetatable(require("date")())] = true
end

--- Compiler configuration
config.compiler = {
    boolean = {
        ["true"] = true,
        ["false"] = true
    },
    special = {
        ["true"] = "true",
        ["false"] = "false",
        ["nil"] = "nil",
        ["null"] = "nil"
    },
    --- danger variables names
    reserved_words = {
        ["and"] = true,
        ["break"] = true,
        ["do"] = true,
        ["else"] = true,
        ["elseif"] = true,
        ["end"] = true,
        ["false"] = true,
        ["for"] = true,
        ["function"] = true,
        ["if"] = true,
        ["in"] = true,
        ["local"] = true,
        ["nil"] = true,
        ["not"] = true,
        ["or"] = true,
        ["repeat"] = true,
        ["return"] = true,
        ["then"] = true,
        ["true"] = true,
        ["until"] = true,
        ["while"] = true,
    },
    --- correspondence table for math operators
    math_ops = {
        ["+"] = "+",
        ["-"] = "-",
        ["/"] = "/",
        ["*"] = "*",
        ["%"] = "%",
        ["**"] = "^",
    },
    --- correspondence table for comparison operators
    comparison_ops = {
        ["=="] = "==",
        ["!="] = "~=",
        [">="] = ">=",
        ["<="] = "<=",
        ["<"]  = "<",
        [">"]  = ">",
    },
    --- correspondence table for logic operators
    logic_ops = {
        ["and"] = "and",
        ["or"] = "or"
    },
    other_ops = {
        ["~"] = true,
        ["|"] = true,
        ["."] = true,
        ["["] = true,
        ["]"] = true,
        [","] = true
    },
    --- reserved variables names
    reserved_vars = {
        _self = true,
        _context = true,
        _charset = true,
        __ = true
    },

    tag_type = {
        EXPRESSION = 1,
        CONTROL = 2,
        COMMENT = 3,
    },

    strip = {
        ["-"] = "%s",
        ["~"] = "[ \t]"
    }
}

config.tokenizer = {
    patterns = {
        NUMBER1 = '^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+', -- 123.45e-32
        NUMBER2 = '^[%+%-]?%d+%.?%d*',
        NUMBER3 = '^0x[%da-fA-F]+',
        NUMBER4 = '^%d+%.?%d*[eE][%+%-]?%d+',
        NUMBER5 = '^%d+%.?%d*',
        WORD = '^[%a_][%w_]*',
        WSPACE = '^%s+',
        STRING1 = "^(['\"])%1", -- empty string
        STRING2 = [[^(['"])(\*)%2%1]],
        STRING3 = [[^(['"]).-[^\](\*)%2%1]],
        CHAR1 = "^''",
        CHAR2 = [[^'(\*)%1']],
        CHAR3 = [[^'.-[^\](\*)%1']],
        PREPRO = '^#.-[^\\]\n',
    }
}

config.loop = {
    keys = {
        parent = true,
        iteration = true,
        index = true,
        index0 = true,
        revindex = true,
        revindex0 = true,
        first = true,
        last = true,
        length = true,
        prev_item = true,
        next_item = true,

        --- trees
        depth = true,
        depth0 = true,
        first_child = true,
        last_child = true,
        trace = true
    }
}

config.macro = {
    import_type = {
        GROUP = 1,
        SINGLE = 2
    }
}

config.escapers = {}

return config