local tonumber = tonumber
local pairs = pairs
local next = next
local pcall = pcall
local type = type
local math = math
local strlen = string.len
local format = string.format
local byte = string.byte
local insert = table.insert
local isarray = table.isarray -- new luajit feature (https://github.com/openresty/luajit2#tableisarray)
local concat = table.concat
local tostring = tostring
local getmetatable = getmetatable
local batch = require("aspect.utils.batch")
local nkeys = require("aspect.utils").nkeys
local var_dump = require("aspect.utils").var_dump
local output = require("aspect.output")
local tablex = require("pl.tablex")
local stringx = require("pl.stringx")
local array2d = require("pl.array2d")
local cjson = require("cjson.safe")
local date = require("date")
local upper = string.upper
local lower = string.lower
local gsub = string.gsub
local sub = string.sub
local config = require("aspect.config")
local e_pattern = config.escape.pattern
local e_replaces = config.escape.replaces
local escapers = config.escapers
local has_utf8, utf8 = pcall(require, "lua-utf8")
if has_utf8 then
    strlen = utf8.len
    upper = utf8.upper
    lower = utf8.lower
    sub   = utf8.sub
end

--- @class aspect.filters
local filters = {
    info = {},
    fn = {}
}

--- Add filter
--- @param name string the filter name
--- @param args table the filter argument list
--- @param func fun the filter function
function filters.add(name, info, func)
    filters.info[name] = {
        input = info.input or 'any',
        args = info.args or {},
        output = info.output or 'any'
    }
    filters.fn[name] = func
end

filters.add('abs', {
    input = 'number',
    output = 'number'
}, function (v)
    return math.abs(output.n(v))
end)

filters.add('batch', {
    input = 'iterator',
    output = 'iterator',
    args = {
        [1] = {name = 'count', type = 'number'}
    }
}, function (v, c)
    if type(v) == "table" then
        return batch.new(v, output.n(c))
    end
end)

filters.add('round', {
    input = 'number',
    output = 'number',
}, function (v)
    v = output.n(v)
    if v % 1 > 0.5 then
        return math.ceil(v)
    else
        return math.floor(v)
    end
end)

filters.add('column', {
    input = 'iterator',
    output = 'iterator',
    args = {
        [1] = {name = 'column', type = 'any'}
    }
}, function (v, column)
    local ok, res = pcall(array2d.column, v, column)
    if ok then
        return res
    else
        return nil
    end
end)

filters.add('date', {
    input = 'any',
    output = 'any',
    args = {
        [1] = {name = 'format', type = 'string'}
    }
}, function (v, column)
    local dt = date(tostring(v))
    if dt then
        return dt:fmt(fmt)
    else
        return ""
    end
end)

local date_mods = {
    seconds = "addseconds",
    second  = "addseconds",
    secs    = "addseconds",
    sec     = "addseconds",
    minutes = "addminutes",
    minute  = "addminutes",
    mins    = "addmins",
    min     = "addmins",
    hours   = "addhours",
    hour    = "addhours",
    days    = "adddays",
    day     = "adddays",
    months  = "addmonths",
    month   = "addmonths",
    years   = "addyears",
    year    = "addyears",
}

filters.add('date_modify', {
    input = 'any',
    output = 'any',
    args = {
        [1] = {name = 'offset', type = 'any'}
    }
}, function (v, offset)
    local dt = date(tostring(v))

    if dt then
        local typ = type(offset)
        if typ == "table" then
            for k, d in pairs(offset) do
                if date_mods[k] then
                    dt[ date_mods[k] ](dt, tonumber(d))
                end
            end
        elseif typ == "number" then
            dt:addseconds(offset)
        end
        return dt
    else
        return v
    end
end)

filters.add('escape', {
    input = 'string',
    output = 'string',
    args = {
        [1] = {name = 'type', type = 'string'}
    }
}, function (v, typ)
    return filters.fn.e(v, typ)
end)

local function char_to_hex(c)
    return format("%%%02X", byte(c))
end

filters.add('e', {
    input = 'string',
    output = 'string',
    args = {
        [1] = {name = 'type', type = 'string'}
    }
}, function (v, typ)
    v = tostring(v)
    if not typ or typ == "html" then
        return gsub(v, e_pattern, e_replaces)
    elseif typ == "js" then
        return cjson.encode(v)
    elseif typ == "url" then
        v = v:gsub("\n", "\r\n")
        v = v:gsub("([^%w ])", char_to_hex)
        v = v:gsub(" ", "+")
        return v
    elseif escapers[typ] then
        return escapers[type](v)
    end
end)

filters.add('default', {
    input = 'any',
    output = 'any',
    args = {
        [1] = {name = 'default', type = 'any'},
        [2] = {name = 'boolean', type = 'boolean'}
    }
}, function (v, default, boolean)
    if boolean then
        return output.b2(v) or default
    else
        if v == nil then
            return default
        else
            return v
        end
    end
end)

filters.add('first', {
    input = 'iterator',
    output = 'any',
    args = {}
}, function (v)
    local typ = type(v)
    if typ == "table" then
        local mt = getmetatable(v)
        if mt and mt.__pairs then
            for _, f in mt.__pairs(v) do
                return f
            end
        else
            return v[next(v)]
        end
    elseif typ == "string" then
        return sub(v, 1, 1)
    end
    return nil
end)

filters.add('format', {
    input = 'string',
    output = 'string',
    args = {
        [1] = {name = '...', type = 'any'}
    }
}, function (v, ...)
    return format(tostring(v), ...)
end)

filters.add('last', {
    input = 'iterator',
    output = 'any',
    args = {}
}, function (v)
    local typ = type(v)
    if typ == "table" then
        local last
        for _, e in output.iter(v) do
            last = e
        end
        return last
    elseif typ == "string" then
        return sub(v, -2, -1)
    end
    return nil
end)

filters.add('join', {
    input = 'iterator',
    output = 'string',
    args = {
        [1] = {name = 'delim', type = 'string'},
        [2] = {name = 'last_delim', type = 'string'},
    }
}, function (v, delim, last_delim)
    if type(v) == "table" then
        local mt = getmetatable(v)
        if mt and mt.__pairs then
            local t = {}
            for _, val in mt.__pairs(v) do
                insert(t, val)
            end
            return concat(t, delim)
        elseif isarray and isarray(v) then
            return concat(v, delim)
        else
            local t = {}
            for  _, val in pairs(v) do
                insert(t, val)
            end
            return concat(t, delim)
        end
    else
        return tostring(v)
    end
end)

filters.add('json_encode', {
    input = 'any',
    output = 'string',
    args = {}
}, function (v)
    return cjson.encode(v)
end)

filters.add('keys', {
    input = 'iterator',
    output = 'iterator',
    args = {}
}, function (v)
    local typ = type(v)
    if typ == "table" then
        local mt = getmetatable(v)
        if mt and mt.__pairs then
            local t, i = {}, 1
            for k, _ in mt.__pairs(v) do
                t[i] = k
                i = i + 1
            end
            return t
        else
            local t, i = {}, 1
            for  k, _ in pairs(v) do
                t[i] = k
                i = i + 1
            end
            return t
        end
    else
        return {}
    end
end)

filters.add('length', {
    input = 'iterator',
    output = 'number',
    args = {}
}, function (v)
    local typ = type(v)
    if typ == "table" then
        local mt = getmetatable(v)
        if mt and mt.__count then
            return mt.__count(v)
        elseif mt and mt.__pairs then -- has custom iterator. we don't know how much elements will be
            return 0 -- may be return -1 ?
        else
            return nkeys(v)
        end
    elseif typ == "string" or typ == "userdata" then
        return strlen(v)
    else
        return 0
    end
end)

filters.add('lower', {
    input = 'string',
    output = 'string',
    args = {}
}, function (v)
    return lower(tostring(v))
end)

filters.add('upper', {
    input = 'string',
    output = 'string',
    args = {}
}, function (v)
    return upper(tostring(v))
end)

filters.add('merge', {
    input = 'table',
    output = 'table',
    args = {
        [1] = {name = 'items', type = 'table'}
    }
}, function (v, items)
    if type(v) == "table" and type(items) == "table" then
        return tablex.merge(v, items)
    else
        return v or items or {}
    end
end)

filters.add('nl2br', {
    input = 'string',
    output = 'string',
    args = {}
}, function (v)
    return gsub(output.s(v), "\n", "<br/>\n")
end)

filters.add('raw', {
    input = 'any',
    output = 'any',
    args = {}
}, function (v)
    return v
end)

filters.add('replace', {
    input = 'string',
    output = 'string',
    args = {
        [1] = {name = 'from', type = 'any'}
    }
}, function (v, from)
    if type(from) == "table" then
        for k, e in pairs(from) do
            v = stringx.replace(v, tostring(k), output.s(e))
        end
    end
    return v
end)

filters.add('split', {
    input = 'string',
    output = 'iterator',
    args = {
        [1] = {name = 'delim', type = 'string'},
        [2] = {name = 'count', type = 'number'}
    }
}, function (v, delim, c)
    return stringx.split(tostring(v), delim, c)
end)

filters.add('striptags', {
    input = 'string',
    output = 'string',
    args = {}
}, function (v)
    return gsub(output.s(v), "%b<>", " ")
end)

filters.add('trim', {
    input = 'string',
    output = 'string',
    args = {
        [1] = {name = 'what', type = 'string'},
        [2] = {name = 'side', type = 'string'},
    }
}, function (v, what, side)
    if not side then
        return stringx.strip(v, what)
    elseif side == "right" then
        return stringx.rstrip(v, what)
    elseif side == "left" then
        return stringx.lstrip(v, what)
    else
        return stringx.strip(v, what)
    end
end)

filters.add('inthe', {
    input = 'any',
    output = 'boolean',
    args = {
        [1] = {name = 'vals', type = 'any'},
    }
}, function (v, vals)
    if type(vals) == "table" then
        return tablex.find(vals, v) ~= nil
    else
        return stringx.lfind(vals, output.s(v)) ~= nil
    end
end)

return filters