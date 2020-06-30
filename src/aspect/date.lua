local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local type = type
local setmetatable = setmetatable
local os = os
local string = string
local math = math
local var_dump = require("aspect.utils").var_dump
local config = require("aspect.config").date
local utf8 = require("aspect.config").utf8
local month = config.months
local current_offset = os.time() - os.time(os.date("!*t", os.time()))

--- Merge table `b` into table `a`
local function union(a,b)
    for k,x in pairs(b) do
        a[k] = x
    end
    return a
end

local function ctime(d, m, y)
    if utf8.lower then
        m = utf8.lower(m)
    else
        m = string.lower(m)
    end
    if not month[m] then
        return nil
    end
    return {
        year = tonumber(y) or tonumber(os.date("%Y")) or 1970,
        month = month[m],
        day = tonumber(d)
    }
end

--- How to works parsers
--- 1. take `date` parser.
--- 1.1 Iterate by patterns.
--- 1.2 When pattern matched then `match` function will be called.
--- 1.3 `Match` function returns table like os.date("*t") if success, nil if failed (if nil resume 1.1)
--- 2. take `time` parser. search continues with the next character after matched `date`
--- 2.1 Iterate by patterns.
--- 2.2 When pattern matched then `match` function will be called.
--- 2.3 `Match` function returns table like os.date("*t") if success, nil if failed (if nil resume 2.1)
--- 3. take `zone` parser. search continues with the next character after matched `time`
--- 2.1 Iterate by patterns.
--- 2.2 When pattern matched then `match` function will be called.
--- 2.3 `Match` function returns table like os.date("*t") if success, nil if failed (if nil resume 3.1)
--- 4. calculate timestamp
local parsers = {
    date = {
        -- 2020-12-02, 2020.12.02
        {
            pattern = "(%d%d%d%d)[.%-](%d%d)[.%-](%d%d)",
            match = function(y, m , d)
                return {year = tonumber(y), month = tonumber(m), day = tonumber(d)}
            end
        } ,
        -- 02-12-2020, 02.12.2020
        {
            pattern = "(%d%d)[.%-](%d%d)[.%-](%d%d%d%d)",
            match = function(y, m , d)
                return {
                    year = tonumber(y),
                    month = tonumber(m),
                    day = tonumber(d)
                }
            end
        },
        -- rfc 1123: 14 Jan 2020, 14 January 2020
        {
            pattern = "(%d%d)[%s-]+(%a%a+)[%s-]+(%d%d%d%d)",
            match = function(d, m, y)
                return ctime(d, m, y)
            end
        },
        -- rfc 1123: 14 Jan, 14 January
        {
            pattern = "(%d%d)[%s-]+(%a%a+)",
            match = function(d, m)
                return ctime(d, m)
            end
        },
        -- ctime: Jan 14 2020, January 14 2020
        {
            pattern = "(%a%a+)%s+(%d%d)%s+(%d%d%d%d)",
            match = function(m, d, y)
                return ctime(d, m, y)
            end
        },
        -- ctime: Jan 14, January 14
        {
            pattern = "(%a%a+)%s+(%d%d)",
            match = function(m, d)
                return ctime(d, m)
            end
        },
        -- US format MM/DD/YYYY: 12/23/2020
        {
            pattern = "(%d%d)/(%d%d)/(%d%d%d%d)",
            match = function(m, d, y)
                return {
                    year = tonumber(y),
                    month = tonumber(m),
                    day = tonumber(d)
                }
            end
        },
        {
            pattern = "(%d%d)/(%d%d)/(%d%d%d%d)",
            match = function(m, d, y)
                return {
                    year = tonumber(y),
                    month = tonumber(m),
                    day = tonumber(d)
                }
            end
        }
    },
    time = {
        {
            pattern = "(%d%d):(%d%d):?(%d?%d?)",
            match = function(h, m, s)
                return {
                    hour = tonumber(h),
                    min = tonumber(m),
                    sec = tonumber(s) or 0
                }
            end
        }
    },
    zone = {
        -- +03:00, -11, +3:30
        {
            pattern = "([+-])(%d?%d):?(%d?%d?)",
            match = function (mod, h, m)
                local sign = (mod == "-") and -1 or 1
                return {
                    offset = sign * (tonumber(h) * 60 + (tonumber(m) or 0)) * 60
                }
            end
        },
        -- UTC marker
        {
            pattern = "UTC",
            match = function ()
                return {offset = 0}
            end
        },
        -- GMT marker
        {
            pattern = "GMT",
            match = function ()
                return {offset = 0}
            end
        }
    }
}

--- @class aspect.date
--- @param time number it is timestamp (UTC)
--- @param offset number UTC time offset (timezone) is seconds
local date = {
    _NAME = "aspect.date",

    parsers      = parsers,
    local_offset = current_offset,
}


--- Parse about any textual datetime description into a Unix timestamp
--- @param t string
--- @return number UTC timestamp
--- @return table datetime description: year, month, day, hour, min, sec, ...
function date.strtotime(t)
    local from = 1
    local time = {day = 1, month = 1, year = 1970}
    local find, sub, match = utf8.find or string.find, utf8.sub or string.sub, utf8.match or string.match
    for _, parser in ipairs({parsers.date, parsers.time, parsers.zone}) do
        for _, matcher in ipairs(parser) do
            local i, j = find(t, matcher.pattern, from)
            if i then
                local res = matcher.match(match(sub(t, i, j), "^" .. matcher.pattern .. "$"))
                if res then
                    union(time, res)
                    from = j + 1
                    break
                end
            end
        end
    end
    local ts = os.time(time) -- time zone ignores
    if not time.offset then -- no offset parsed - use local offset
        time.offset = current_offset
    else
        ts = ts - (time.offset - current_offset)
    end
    return ts, time
end

--- @param format string date format
--- @param time_zone number|nil UTC time zone offset in seconds
--- @param locale string|nil month and week language
--- @return string
function date:format(format, time_zone, locale)
    locale = locale or 'en'
    local utc = false
    local time = self.time
    local offset = time_zone or current_offset
    if format:sub(1, 1) == "!" then
        utc = true
        offset = 0
    else
        format = "!" .. format
        utc = false
        time = time + offset
    end
    --- replace aliases
    format = string.gsub(format, "%$(%w)", config.aliases)
    --- replace localizable specs
    local d = os.date("!*t", time)
    format = string.gsub(format, "%%([zZaAbB])", function (spec)
        if spec == "a" or spec == "A" then
            local i, from = d.wday - 1, nil -- there 1 is sunday, shut up ISO8601[2.2.8]
            if i == 0 then
                i = 7
            end
            from = config.week_locale[locale] or config.week_locale['en']
            if spec == "A" then
                return from[i][2]
            else
                return from[i][1]
            end
        elseif spec == "b" or spec == "B" then
            local from = config.months_locale[locale] or config.months_locale['en']
            if spec == "B" then
                return from[d.month][2]
            else
                return from[d.month][1]
            end
        elseif spec == "z" then
            return self.get_timezone(offset, "")
        elseif spec == "Z" then
            return self.get_timezone(offset, ":", true)
        end
        return '%' .. spec
    end)
    --var_dump({format = format, time = time, offset_h = offset / 60, utc = utc, zone = self.get_timezone(offset, ":")})
    return os.date(format, time)
end

--- Returns offset as time zone
--- @param offset number in seconds
--- @param delim string hours and minutes delimiter
--- @param short boolean use short format
--- @return string like +03:00 or +03
function date.get_timezone(offset, delim, short)
    delim = delim or ":"
    local sign = (offset < 0) and '-' or '+'
    if offset == 0 then
        if short then
            return ""
        else
            return sign .. "0000"
        end
    end
    offset = math.abs(offset / 60) -- throw away seconds and sign
    local h = offset / 60
    local m = offset % 60
    if short then
        if m == 0 then
            return string.format(sign .. "%d", h, m)
        else
            return string.format(sign .. "%d" .. delim .. "%02d", h, m)
        end
    else
        return string.format(sign .. "%02d" .. delim .. "%02d", h, m)
    end
end

--- @return string
function date:__tostring()
    return self:format("%F %T UTC%Z")
end

--- @param b any
--- @return string
function date:__concat(b)
    return tostring(self) .. tostring(b)
end

--- @param b any
--- @return aspect.date
function date:__add(b)
    return date.new(self.time + date.new(b).time, self.offset)
end

--- @param b any
--- @return aspect.date
function date:__sub(b)
    return date.new(self.time - date.new(b).time, self.offset)
end

--- @param b number
--- @return aspect.date
function date:__mul(b)
    if type(b) == "number" and b > 0 then
        return date.new(self.time * b, self.offset)
    else
        return self
    end
end

--- @param b number
--- @return aspect.date
function date:__div(b)
    if type(b) == "number" and b > 0 then
        return date.new(self.time / b, self.offset)
    else
        return self
    end
end

function date:__eq(b)
    return self.time == date.new(b).time
end

--- @param b any
--- @return boolean
function date:__lt(b)
    return self.time < date.new(b).time
end

--- @param b any
--- @return boolean
function date:__le(b)
    return self.time <= date.new(b).time
end

local date_mods = {
    seconds = "sec",
    second  = "sec",
    secs    = "sec",
    sec     = "sec",
    minutes = "min",
    minute  = "min",
    mins    = "min",
    min     = "min",
    hours   = "hour",
    hour    = "hour",
    days    = "day",
    day     = "day",
    months  = "month",
    month   = "month",
    years   = "year",
    year    = "year",
}

function date:modify(t)
    local d = os.date("*t", self.time)
    for k, v in pairs(t) do
        if date_mods[k] then
            local name = date_mods[k]
            d[name] = d[name] + v
        end
    end
    self.time = os.time(d)
    return self
end


local mt = {
    __index = date,
    __tostring = date.__tostring,
    __add = date.__add,
    __sub = date.__sub,
    __mul = date.__mul,
    __div = date.__div,
    __eq = date.__eq,
    __lt = date.__lt,
    __le = date.__le,
}


function date.new(t, offset)
    local typ, time, info = type(t), 0, {}
    offset = offset or 0
    if typ == "number" then
        time = t
    elseif typ == "table" then
        if t._NAME == date._NAME then
            return t
        else
            local _t = {year = 1970, month = 1, day = 1}
            union(_t, t)
            time = os.time(_t)
        end
    elseif typ == "string" or typ == "userdata" then
        time, info = date.strtotime(tostring(t))
        offset = info.offset
    else
        time = os.time()
    end

    return setmetatable({
        time = time,
        offset = offset,
        info = info
    }, mt)
end

return date