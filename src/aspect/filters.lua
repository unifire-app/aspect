local type = type
local math = math
local concat = table.concat
local has_utf8, utf8 = pcall(require, "utf8")
local tablex = require("pl.tablex")
local stringx = require("pl.stringx")
local array2d = require("pl.array2d")
local cjson = require("cjson.safe")

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
function filters.date(v, format)

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

end

--- https://twig.symfony.com/doc/2.x/filters/format.html
function filters.format(v, ...)

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
    return tablex.keys(v)
end

--- https://twig.symfony.com/doc/2.x/filters/length.html
function filters.length(v)

end

--- https://twig.symfony.com/doc/2.x/filters/lower.html
function filters.lower(v)

end

--- https://twig.symfony.com/doc/2.x/filters/upper.html
function filters.upper(v)

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