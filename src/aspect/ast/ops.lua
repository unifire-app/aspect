local quote_string = require("pl.stringx").quote_string

--- The operator settings
--- @class aspect.ast.op
--- @field order number
--- @field name string
--- @field type string
--- @field pack fun(l:string, r:string, c:string)
--- @field delimiter string|nil
--- @field brackets boolean
--- @field c string|nil
--- @field l string|nil
--- @field r string
--- @field out string
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
        type  = "binary",
        l     = "any",
        r     = "any",
        out   = "boolean",
        pack  = function (left, right, test)
            if test["not"] then
                return "not __.test(" .. left .. ", " .. quote_string(test.name)  .. ", " .. right .. ")"
            else
                return "__.test(" .. left .. ", " .. quote_string(test.name)  .. ", " .. right .. ")"
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
        pack  = function (left, right, opts)
            if opts["not"] then
                return "not __.f['in'](" .. left .. ", " .. right .. ")"
            else
                return "__.f['in'](" .. left .. ", " .. right .. ")"
            end
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
        type  = "ternary",
        delimiter = ":",
        c     = "boolean",
        l     = "any",
        r     = "any",
        out   = "any",
        brackets = true,
        pack  = function (left, right, cond)
            return "(" .. cond .. ") and (" .. left .. ") or (" .. right .. ")"
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