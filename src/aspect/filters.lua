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
function filters.add(name, val_type, ret_type, args, func)
    filters.info[name] = {
        val = val_type,
        args = args,
        ret = ret_type
    }
    filters.fn[name] = func
end

--filters.add("abs", "number", "number", {}, math.abs)

function filters.fn.abs(v)
    return math.abs(output.n(v))
end

--filters.add("abs", "table", "iterator", {
--    {name = "count", type = "number"}
--}, batch.new)

function filters.fn.batch(v, c)
    if type(v) == "table" then
        return batch.new(v, output.n(c))
    end
end

function filters.fn.round(v)
    v = output.n(v)
    if v % 1 > 0.5 then
        return math.ceil(v)
    else
        return math.floor(v)
    end
end

function filters.fn.column(v, column)
    local ok, res = pcall(array2d.column, v, column)
    if ok then
        return res
    else
        return nil
    end
end

function filters.fn.date(v, fmt)
    local dt = date(tostring(v))
    if dt then
        return dt:fmt(fmt)
    else
        return ""
    end
end

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

function filters.fn.date_modify(v, offset)
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
end

function filters.fn.escape(v, typ)
    return filters.fn.e(v, typ)
end

local function char_to_hex(c)
    return format("%%%02X", byte(c))
end

function filters.fn.e(v, typ)
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
end

function filters.fn.default(v, default, boolean)
    if boolean then
        return output.b2(v) or default
    else
        if v == nil then
            return default
        else
            return v
        end
    end
end

function filters.fn.first(v)
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
end

function filters.fn.format(v, ...)
    return format(tostring(v), ...)
end

function filters.fn.last(v)
    local typ = type(v)
    if typ == "table" then
        local last
        for _, e in output.i(v) do
            last = e
        end
        return last
    elseif typ == "string" then
        return sub(v, -2, -1)
    end
    return nil
end

function filters.fn.join(v, delim, last_delim)
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
end

--- https://twig.symfony.com/doc/2.x/filters/json_encode.html
function filters.fn.json_encode(v)
    return cjson.encode(v)
end

--- https://twig.symfony.com/doc/2.x/filters/keys.html
function filters.fn.keys(v)
    local typ = type(v)
    if typ == "table" then
        if v.__pairs and getmetatable(v).__pairs then
            local keys, i = {}, 1
            for k, _ in v:__pairs() do
                keys[i] = k
                i = i + 1
            end
            return keys
        else
            return tablex.keys(v)
        end
    else
        return {}
    end
end

function filters.fn.length(v)
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
end

function filters.fn.lower(v)
    return lower(tostring(v))
end

function filters.fn.upper(v)
    return upper(tostring(v))
end

function filters.fn.merge(v, items)
    if type(v) == "table" and type(items) == "table" then
        return tablex.merge(v, items)
    else
        return v or items or {}
    end
end

function filters.fn.nl2br(v)
    return gsub(output.s(v), "\n", "<br/>\n")
end

function filters.fn.raw(v)
    return v
end

function filters.fn.replace(v, from)
    if type(from) == "table" then
        for k, e in pairs(from) do
            v = stringx.replace(v, tostring(k), output.s(e))
        end
    end
    return v
end

function filters.fn.split(v, delim, c)
    return stringx.split(tostring(v), delim, c)
end

function filters.fn.striptags(v)
    return gsub(output.s(v), "%b<>", " ")
end

function filters.fn.trim(v, what, side)
    if not side then
        return stringx.strip(v, what)
    elseif side == "right" then
        return stringx.rstrip(v, what)
    elseif side == "left" then
        return stringx.lstrip(v, what)
    else
        return stringx.strip(v, what)
    end
end

function filters.fn.inthe(v, k)
    if type(k) == "table" then
        return tablex.find(k, v) ~= nil
    else
        return stringx.lfind(k, output.s(v)) ~= nil
    end
end

function filters.fn.split(v, delim, limit)
    return stringx.split(output.s(v), output.s(delim), limit) or {}
end

return filters