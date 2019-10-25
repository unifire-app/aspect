local type = type
local math = math
local strlen = string.len
local format = string.format
local concat = table.concat
local tostring = tostring
local getmetatable = getmetatable
local tablex = require("pl.tablex")
local stringx = require("pl.stringx")
local array2d = require("pl.array2d")
local cjson = require("cjson.safe")
local count = table.nkeys or tablex.size
local upper = string.upper
local lower = string.lower
local has_utf8, utf8 = pcall(require, "lua-utf8")
if has_utf8 then
    strlen = utf8.len
    upper = utf8.upper
    lower = utf8.lower
end

if table.nkeys then -- new luajit function
    count = table.nkeys
end

local filters = {}

--- https://twig.symfony.com/doc/2.x/filters/abs.html
function filters.abs(v)
    return math.abs(v)
end

--- https://twig.symfony.com/doc/2.x/filters/batch.html
function filters.batch(v)

end

--- https://twig.symfony.com/doc/2.x/filters/column.html
function filters.column(v, column)
    return array2d.column(v, column)
end

--- https://twig.symfony.com/doc/2.x/filters/date.html
function filters.date(v, fmt)

end

--- https://twig.symfony.com/doc/2.x/filters/date_modify.html
function filters.date_modify(v, offset)

end

--- https://twig.symfony.com/doc/2.x/filters/escape.html
function filters.escape(v, typ)
    return filters.e(v, typ)
end

function filters.e(v, typ)

end

--- https://twig.symfony.com/doc/2.x/filters/default.html
function filters.default(v, default)
    if v == nil then
        return default
    else
        return v
    end
end

--- https://twig.symfony.com/doc/2.x/filters/first.html
function filters.first(v)
    local typ = type(v)
    if typ == "table" then

    else
        return nil
    end
end

--- https://twig.symfony.com/doc/2.x/filters/format.html
function filters.format(v, ...)
    return format(tostring(v), ...)
end

--- https://twig.symfony.com/doc/2.x/filters/last.html
function filters.last(v)

end

--- https://twig.symfony.com/doc/2.x/filters/format_number.html
function filters.format_number(v, opts)

end

function filters.markdown_to_html(v, opts)

end

--- https://twig.symfony.com/doc/2.x/filters/join.html
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
        if v.__count and getmetatable(v).__count then
            return v:__count()
        elseif v.__pairs and getmetatable(v).__pairs then -- has custom iterator. we don't know how much elements will be
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