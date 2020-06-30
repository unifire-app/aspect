local pcall = pcall
local require = require
local getmetatable = getmetatable

--- Internal configuration of
--- Aspect Template Engine. Be careful.
--- @class aspect.config
local config = {}

--- JSON configuration
config.json = {
    encode = nil,
    decode = nil,
    error = "JSON encode/decode no available. Please install `cjson` or `json` or configure `require('aspect.config').json` before using Aspect"
}

--- UTF8 configuration
config.utf8 = {
    len   = nil,
    lower = nil,
    upper = nil,
    sub   = nil,
    match = nil,
}

config.env = {

}

--- escape filter settings (HTML strategy)
config.escape = {
    pattern = "[}{\"><'&]",
    replaces = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#39;"
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
        config.json.encode = cjson.encode
        config.json.decode = cjson.decode
    else
        local has_json, json = pcall(require, "json")
        if has_json then
            config.json.encode = json.encode
            config.json.decode = json.decode
            if json.null then
                config.is_false[json.null] = true
                config.is_empty_string[json.null] = true
            end
            if json.empty_array then
                config.is_false[json.empty_array] = true
            end
        end
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

    --- https://www.tarantool.io/ru/doc/2.4/reference/reference_lua/msgpack/
    local has_msgpack, msgpack = pcall(require, "msgpack")
    if has_msgpack then
        config.is_false[msgpack.NULL] = true
        config.is_empty_string[msgpack.NULL] = true
    end

    --- https://www.tarantool.io/en/doc/2.4/reference/reference_lua/box_null/
    if box and box.NULL then
        config.is_false[box.NULL] = true
        config.is_empty_string[box.NULL] = true
    end
end

--- Detect UTF8 module
do
    local utf8
    for _, name in ipairs({"lua-utf8", "utf8", "lutf8"}) do
        local ok, module = pcall(require, name)
        if ok then
            utf8 = module
            break
        end
    end
    if utf8 then
        config.utf8.len   = utf8.len or utf8.length
        config.utf8.upper = utf8.upper
        config.utf8.lower = utf8.lower
        config.utf8.sub   = utf8.sub
        config.utf8.match = utf8.match
        config.utf8.find  = utf8.find
    end
end

--- Compiler configuration
config.compiler = {
    is_boolean = {
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
        NUMBER2 = '^[%+%-]?%d+%.?%d*', -- 123 or 123.456
        NUMBER3 = '^0x[%da-fA-F]+', -- 0xDeadBEEF
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
        has_more = true,

        --- trees
        level = true,
        level0 = true,
        first_node = true,
        last_node = true,
        path = true
    }
}

config.macro = {
    import_type = {
        GROUP = 1,
        SINGLE = 2
    }
}

config.escapers = {}

config.date = {
    months = {
        ["jan"] = 1,  ["january"]   = 1,
        ["feb"] = 2,  ["february"]  = 2,
        ["mar"] = 3,  ["march"]     = 3,
        ["apr"] = 4,  ["april"]     = 4,
        ["may"] = 5,  ["may"]       = 5,
        ["jun"] = 6,  ["june"]      = 6,
        ["jul"] = 7,  ["july"]      = 7,
        ["aug"] = 8,  ["august"]    = 8,
        ["sep"] = 9,  ["september"] = 9,
        ["oct"] = 10, ["october"]   = 10,
        ["nov"] = 11, ["november"]  = 11,
        ["dec"] = 12, ["december"]  = 12,
    },
    months_locale = {
        en = {
            [1]  = {"Jan", "January"},
            [2]  = {"Feb", "February"},
            [3]  = {"Mar", "March"},
            [4]  = {"Apr", "April"},
            [5]  = {"May", "May"},
            [6]  = {"Jun", "June"},
            [7]  = {"Jul", "July"},
            [8]  = {"Aug", "August"},
            [9]  = {"Sep", "September"},
            [10] = {"Oct", "October"},
            [11] = {"Nov", "November"},
            [12] = {"Dec", "December"},
        }
    },
    week = {
        ["mon"] = 1, ["monday"]    = 1,
        ["tue"] = 2, ["tuesday"]   = 2,
        ["wed"] = 3, ["wednesday"] = 3,
        ["thu"] = 4, ["thursday"]  = 4,
        ["fri"] = 5, ["friday"]    = 5,
        ["sat"] = 6, ["saturday"]  = 6,
        ["sun"] = 7, ["sunday"]    = 7,
    },
    week_locale = {
        en = {
            [1] = {"Mon", "Monday"},
            [2] = {"Tue", "Tuesday"},
            [3] = {"Wed", "Wednesday"},
            [4] = {"Thu", "Thursday"},
            [5] = {"Fri", "Friday"},
            [6] = {"Sat", "Saturday"},
            [7] = {"Sun", "Sunday"},
        },
    },
    aliases = {
        c = "%a %b %d %H:%m%s %Y",
        r = "%I:%M:%S %p",
        R = "%I:%M",
        T = "%H:%M:%S",
        D = "%m/%d/%y",
        F = "%Y-%m-%d"
    }
}

return config