local tonumber = tonumber
local pairs = pairs
local next = next
local pcall = pcall
local type = type
local math = math
local strlen = string.len
local format = string.format
local concat = table.concat
local tostring = tostring
local getmetatable = getmetatable
local batch = require("aspect.utils.batch")
local output = require("aspect.output")
local tablex = require("pl.tablex")
local stringx = require("pl.stringx")
local array2d = require("pl.array2d")
local cjson = require("cjson.safe")
local date = require("date")
local count = table.nkeys or tablex.size
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

if table.nkeys then -- new luajit function
    count = table.nkeys
end

local filters = {}

function filters.abs(v)
    return math.abs(output.n(v))
end

function filters.batch(v, c)
    return batch.new(v, output.n(c))
end

function filters.column(v, column)
    local ok, res = pcall(array2d.column, v, column)
    if ok then
        return res
    else
        return nil
    end
end

function filters.date(v, fmt)
    local dt = date(tostring(v))
    if dt then
        return dt:fmt(fmt)
    else
        return ""
    end
end

function filters.date_modify(v, offset)
    local dt = date(tostring(v))
    if dt then
        local typ = type(offset)
        if typ == "table" then
            for k, d in pairs(offset) do
                if dt["set" .. k] then
                    dt["set" .. k](dt, tonumber(d))
                end
            end
        elseif typ == "number" then
        end
    else
        return v
    end
end

function filters.escape(v, typ)
    return filters.e(v, typ)
end

function filters.e(v, typ)
    v = tostring(v)
    if not typ or typ == "html" then
        gsub(v, e_pattern, e_replaces)
    elseif typ == "js" then
        return cjson.encode(v)
    elseif escapers[typ] then
        return escapers(v)
    end
end

function filters.default(v, default, boolean)
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

function filters.first(v)
    local typ = type(v)
    if typ == "table" then
        local mt = getmetatable(v)
        if mt.__pairs then
            for _, f in mt.__pairs(v) do
                return f
            end
        else
            return next(v)
        end
    elseif typ == "string" then
        return sub(v, 1, 1)
    end
    return nil
end

function filters.format(v, ...)
    return format(tostring(v), ...)
end

function filters.last(v)

end

function filters.format_number(v, opts)

end

function filters.markdown_to_html(v, opts)

end

function filters.join(v, delim, last_delim)
    return concat(v, delim)
end

--- https://twig.symfony.com/doc/2.x/filters/json_encode.html
function filters.json_encode(v)
    return cjson.encode(v)
end

--- https://twig.symfony.com/doc/2.x/filters/keys.html
function filters.keys(v)
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

--- https://twig.symfony.com/doc/2.x/filters/length.html
function filters.length(v)
    local typ = type(v)
    if typ == "table" then
        local mt = getmetatable(v)
        if mt and mt.__count then
            return mt.__count(v)
        elseif mt and mt.__pairs then -- has custom iterator. we don't know how much elements will be
            return 0 -- may be return -1 ?
        else
            return count(v)
        end
    elseif typ == "string" or typ == "userdata" then
        return strlen(v)
    else
        return 0
    end
end

--- https://twig.symfony.com/doc/2.x/filters/lower.html
function filters.lower(v)
    return lower(tostring(v))
end

--- https://twig.symfony.com/doc/2.x/filters/upper.html
function filters.upper(v)
    return upper(tostring(v))
end

--- https://twig.symfony.com/doc/2.x/filters/map.html
function filters.map(v, formatter)

end

--- https://twig.symfony.com/doc/2.x/filters/merge.html
function filters.merge(v, items)

end

--- https://twig.symfony.com/doc/2.x/filters/nl2br.html
function filters.nl2br(v)

end

--- https://twig.symfony.com/doc/2.x/filters/raw.html
function filters.raw(v)

end

--- https://twig.symfony.com/doc/2.x/filters/replace.html
function filters.replace(v)

end

--- https://twig.symfony.com/doc/2.x/filters/split.html
function filters.split(v, delim, count)

end

--- https://twig.symfony.com/doc/2.x/filters/striptags.html
function filters.striptags(v, tags)

end

--- https://twig.symfony.com/doc/2.x/filters/url_encode.html
function filters.url_encode(v)

end

--- https://twig.symfony.com/doc/2.x/filters/trim.html
function filters.trim(v)
    return stringx.strip(v)
end

return filters