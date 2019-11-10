local require = require
local quote_string = require("pl.stringx").quote_string
local var_dump = require("aspect.utils").var_dump

--- The operator settings
--- @class aspect.ast.op
--- @field order number operator precedence (from lower to higher)
--- @field token string operator template token
--- @field type string type of operator& one of: unary, binary, ternary
--- @field parser fun(c:aspect.compiler, tok:aspect.tokenizer) how to parse operator in the template, returns cond
--- @field pack fun(l:string, r:string, c:string) how to pack lua code
--- @field delimiter string|nil ternary delimiter
--- @field brackets boolean operator in brackets
--- @field c string|nil data type of condition branch
--- @field l string|nil data type of left member (branch)
--- @field r string data type of right member (branch)
--- @field out string data type of operator's result
local _op = {}

local ops = {
    -- **
    {
        order = 4,
        token = "**",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " ^ " .. right
        end
    },
    -- - (unary)
    {
        order = 5,
        token = "-",
        type  = "unary",
        r     = "number",
        out   = "number",
        pack  = function (_, right)
            return "-" .. right
        end
    },
    -- not (unary)
    {
        order = 5,
        token = "not",
        type  = "unary",
        r     = "boolean",
        out   = "boolean",
        pack  = function (_, right)
            return "not " .. right
        end
    },

    -- is, is not
    {
        order = 6,
        token = "is",
        type  = "unary",
        r     = "any",
        out   = "boolean",
        parse = function (compiler, tok)
            return compiler:parse_is(tok), "test"
        end,
        pack  = function (left, right, test)
            local expr = "__.opts.t.is_" .. test.name .. "(__, " .. right .. ", " .. (test.expr or "nil") .. ")"
            if test["not"] then
                return "not " .. expr
            else
                return expr
            end
        end
    },

    -- in, not in
    {
        order = 6,
        token = "in",
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "boolean",
        pack  = function (left, right)
            return "__.f.inthe(" .. left .. ", " .. right .. ")"
        end
    },
    {
        order = 6,
        token = "not",
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "boolean",
        parse = function (compiler, tok)
            tok:require("not"):next():require("in"):next()
        end,
        pack  = function (left, right)
            return "not __.f.inthe(" .. left .. ", " .. right .. ")"
        end
    },

    -- *, /, //, %
    {
        order = 7,
        token = "*",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " * " .. right
        end
    },
    {
        order = 7,
        token = "/",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " / " .. right
        end
    },
    {
        order = 7,
        token = "//",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return "__.floor(" .. left .. " / " .. right .. ")"
        end
    },
    {
        order = 7,
        token = "%",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " % " .. right
        end
    },

    -- +, -
    {
        order = 8,
        token = "+",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " + " .. right
        end
    },
    {
        order = 8,
        token = "-",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "number",
        pack  = function (left, right)
            return left .. " - " .. right
        end
    },

    -- ~
    {
        order = 9,
        token = "~",
        type  = "binary",
        l     = "string",
        r     = "string",
        out   = "string",
        pack  = function (left, right)
            return left .. " .. " .. right
        end
    },

    -- <, >, <=, >=, !=, ==
    {
        order = 10,
        token = "<",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " < " .. right
        end
    },
    {
        order = 10,
        token = ">",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " > " .. right
        end
    },
    {
        order = 10,
        token = "<=",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " <= " .. right
        end
    },
    {
        order = 10,
        token = ">=",
        type  = "binary",
        l     = "number",
        r     = "number",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " >= " .. right
        end
    },
    {
        order = 10,
        token = "!=",
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " ~= " .. right
        end
    },
    {
        order = 10,
        token = "==",
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " == " .. right
        end
    },

    -- ?:, ??
    {
        order = 11,
        token = "??",
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "any",
        brackets = true,
        pack  = function (left, right)
            return left .. " and " .. right
        end
    },
    {
        order = 11,
        token = "?:",
        type  = "binary",
        l     = "boolean|any",
        r     = "any",
        out   = "any",
        brackets = true,
        pack  = function (left, right)
            return left .. " or " .. right
        end
    },

    -- ? ... : ...
    {
        order = 12,
        token = "?",
        type  = "binary", -- yeah, be binary
        delimiter = ":",
        c     = "any",     -- center
        l     = "boolean", -- left
        r     = "any",     -- right
        out   = "any",
        brackets = true,
        --- @param compiler aspect.compiler
        --- @param tok aspect.tokenizer
        parse = function (compiler, tok)
            local ast = require("aspect.ast").new()
            local root = ast:parse(compiler, tok:require("?"):next()):get_root()
            tok:require(":"):next()
            --var_dump("ROOT", root)
            return root
        end,
        pack  = function (left, right, center)
            return "(" .. left .. ") and (" .. center .. ") or (" .. right .. ")"
        end
    },

    -- and
    {
        order = 13,
        token = "and",
        type  = "binary",
        l     = "boolean",
        r     = "boolean",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " and " .. right
        end
    },

    -- or
    {
        order = 14,
        token = "or",
        type  = "binary",
        l     = "boolean",
        r     = "boolean",
        out   = "boolean",
        pack  = function (left, right)
            return left .. " or " .. right
        end
    },
}

return ops