local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local type = type
local concat = table.concat
local insert = table.insert
local getn = table.getn
local str_rep  = string.rep
local sub = string.sub
local find = string.find
local reverse = string.reverse
local gmatch = string.gmatch
local format = string.format
local getmetatable = getmetatable
local nkeys = table.nkeys -- luajit 2.1
local isarray = table.isarray -- luajit 2.1
local pcall = pcall
local select = select

local utils = {
    starts_with = string.startswith
}

--- Total number of elements in this table.
--- Supported __len metamethod and table.nkeys (if possible)
--- Note: iterators (tables with __paris metamethod) returns 0
--- @param t table
--- @param iterate boolean if t is iterator (has __pairs) then iterate it
--- @return number
function utils.nkeys(t, iterate)
    local mt = getmetatable(t)
    if mt then
        if mt.__len then
            return t:__len()
        elseif mt.__pairs then -- skip iterators
            if iterate then
                local i = 0
                for _ in mt.__pairs(t) do i = i + 1 end
                return i
            else
                return 0
            end
        end
    elseif nkeys then
        return nkeys(t)
    elseif isarray and isarray(t) then
        return getn(t)
    else
        local i = 0
        for _ in pairs(t) do i = i + 1 end
        return i
    end
end

--- Escape any Lua 'magic' characters in a string
--- @param s string the input string
--- @return string
function utils.escape(s)
    return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'))
end

--- Trim any whitespace or present chars
--- @param s string
--- @param left boolean
--- @param right boolean
--- @param chrs string|nil
--- @return string
function utils.trim(s, left, right, chrs)
    if not chrs then
        chrs = '%s'
    else
        chrs = '[' .. utils.escape(chrs) .. ']'
    end
    local f = 1
    local t
    if left then
        local i1, i2 = find(s,'^'..chrs..'*')
        if i2 >= i1 then
            f = i2+1
        end
    end
    if right then
        if #s < 200 then
            local i1,i2 = find(s,chrs..'*$',f)
            if i2 >= i1 then
                t = i1-1
            end
        else
            local rs = reverse(s)
            local i1,i2 = find(rs, '^'..chrs..'*')
            if i2 >= i1 then
                t = -i2
            end
        end
    end
    return sub(s,f,t)
end

--- @param s string
--- @return string
function utils.strip(s)
    return utils.trim(s, true, true)
end

--- Count all instances of substring in string.
--- @param s string
--- @param subs string
---
function utils.strcount(s, subs)
    local i1,i2 = find(s, subs, nil, true)
    local k = 0
    while i1 do
        if i2 > #s then break end
        k = k + 1
        i1,i2 = find(s, subs, i2+1, true)
    end
    return k
end

--- Utility function that finds any patterns that match a long string's an open or close.
-- Note that having this function use the least number of equal signs that is possible is a harder algorithm to come up with.
-- Right now, it simply returns the greatest number of them found.
-- @param s The string
-- @return 'nil' if not found. If found, the maximum number of equal signs found within all matches.
local function has_lquote(s)
    local lstring_pat = '([%[%]])(=*)%1'
    local equals, new_equals, _
    local finish = 1
    repeat
        _, finish, _, new_equals = s:find(lstring_pat, finish)
        if new_equals then
            equals = max(equals or 0, #new_equals)
        end
    until not new_equals

    return equals
end

--- Quote the given string and preserve any control or escape characters, such that reloading the string in Lua returns the same result.
--- @param s string the string to be quoted.
--- @return string the quoted string.
function utils.quote_string(s)
    -- Find out if there are any embedded long-quote sequences that may cause issues.
    -- This is important when strings are embedded within strings, like when serializing.
    -- Append a closing bracket to catch unfinished long-quote sequences at the end of the string.
    local equal_signs = has_lquote(s .. "]")

    -- Note that strings containing "\r" can't be quoted using long brackets
    -- as Lua lexer converts all newlines to "\n" within long strings.
    if (s:find("\n") or equal_signs) and not s:find("\r") then
        -- If there is an embedded sequence that matches a long quote, then
        -- find the one with the maximum number of = signs and add one to that number.
        equal_signs = ("="):rep((equal_signs or -1) + 1)
        -- Long strings strip out leading newline. We want to retain that, when quoting.
        if s:find("^\n") then s = "\n" .. s end
        local lbracket, rbracket =
        "[" .. equal_signs .. "[",
        "]" .. equal_signs .. "]"
        s = lbracket .. s .. rbracket
    else
        -- Escape funny stuff. Lua 5.1 does not handle "\r" correctly.
        s = ("%q"):format(s):gsub("\r", "\\r")
    end
    return s
end

--- @param t table
--- @return table
function utils.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        insert(keys, k)
    end
    return keys
end

--- Merge two tables and returns lua representation. Value of table are expressions.
--- @param t1 table|nil
--- @param t2 table|nil
--- @return string|nil
function utils.implode_hashes(t1, t2)
    local r = {}
    if t1 then
        for k,v in pairs(t1) do
            if type(k) == "number" then
                r[#r + 1] = '[' .. k .. '] = ' .. v
            else
                r[#r + 1] = '["' .. k .. '"] = ' .. v
            end
        end
        if t2 then
            for k,v in pairs(t2) do
                if not t1[k] then
                    if type(k) == "number" then
                        r[#r + 1] = '[' .. k .. '] = ' .. v
                    else
                        r[#r + 1] = '["' .. k .. '"] = ' .. v
                    end
                end
            end
        end
    elseif t2 then
        for k,v in pairs(t2) do
            if type(k) == "number" then
                r[#r + 1] = '[' .. k .. '] = ' .. v
            else
                r[#r + 1] = '["' .. k .. '"] = ' .. v
            end
        end
    end
    if #r > 0 then
        return concat(r, ",")
    else
        return nil
    end
end

--- Prepend the indexed table to another table
--- @param from table
--- @param to table
function utils.prepend_table(from, to)
    for i, v in ipairs(from) do
        insert(to, i, v)
    end
end

--- Append the indexed table to another table
--- @param from table
--- @param to table
function utils.append_table(from, to)
    for _, v in ipairs(from) do
        insert(to, v)
    end
end

--- Join elements of the table
--- @param t table|string
--- @param delim string
function utils.join(t, delim)
    if type(t) == "table" then
        return concat(t, delim)
    else
        return tostring(t)
    end
end

--- Outputs values to the stderr. For debug only.
function utils.var_dump(...)
    io.stderr:write(utils.dump(...) .. "\n" .. debug.traceback() .. "\n")
end

--- Export arguments as string
--- @return string
function utils.dump(...)
    local output, n, data = {}, select("#", ...), {...};
    for i = 1, n do
        if type(data[i]) == 'table' then
            insert(output, utils.dump_table(data[i], 0, { [tostring(data[i])] = true}))
        else
            insert(output, tostring(data[i]))
        end
    end
    return concat(output, "\n")
end

--- Serialize the table
--- @param tbl table
--- @param indent number отступ в количествах пробелов
--- @return string
function utils.dump_table(tbl, indent, tables)
    if not indent then
        indent = 0
    elseif indent > 16 then
        return "*** too deep ***"
    end
    local output = {};
    local mt = getmetatable(tbl)
    local tab = str_rep("  ", indent + 1)
    local iter, ctx, key
    if mt and mt.__pairs then
        iter, ctx, key = mt.__pairs(tbl)
    else
        iter, ctx, key = pairs(tbl)
    end
    for k, v in iter, ctx, key do
        local formatting = tab
        if type(k) == 'string' then
            formatting = formatting .. k .. " = "
        elseif type(k) ~= 'number' then
            formatting = formatting .. "[" .. tostring(k) .. "]" .. " = "
        end
        if type(v) == "table" then
            if tables[v] then
                insert(output, formatting .. "*** recursion ***\n")
                --output = output .. formatting .. "*** recursion ***\n"
            elseif type(k) == "string" and k:sub(1, 1) == "_" then
                insert(output, formatting .. "(table) " .. "*** private field with table ***\n")
            else
                tables[v] = true
                insert(output, formatting .. utils.dump_table(v, indent + 1, tables) .. "\n")
                tables[v] = nil
            end
        elseif type(v) == "userdata" then
            local ok, str = pcall(tostring, v)
            if not ok then
                str = "*** could not convert to string (userdata): " .. tostring(str) .. " ***"
            end
            insert(output, formatting .. "(" .. type(v) .. ") " .. str .. "\n")
        else
            insert(output, formatting .. "(" .. type(v) .. ") " .. tostring(v) .. "\n")
        end
    end

    if #output > 0 then
        return "{\n" .. concat(output, "") ..  str_rep("  ", indent) .. "}"
    else
        return "{}"
    end
end

function utils.table_export(t)
    local output = {}
    for k, v in pairs(t) do
        local key
        if type(k) == 'string' then
            key =  "[" .. utils.quote_string(k) .. "] = "
        end
        if type(v) == "table" then
            insert(output, k .. utils.table_export_lua(v))
        elseif type(v) == "number" then
            insert(output, k .. v)
        else
            insert(output, k .. utils.quote_string(tostring(v)))
        end
    end
    return "{" .. concat(output, ", ") .. "}"
end

---
--- @param s string
--- @param chrs string|nil
--- @return string
function utils.ltrim(s, chrs)
    local i1,i2 = find(s,'^'.. (chrs or "%s")..'*')
    if i2 >= i1 then
        return sub(s,i2+1)
    end
    return s
end

---
--- @param s string
--- @param chrs string|nil
--- @return string
function utils.rtrim(s, chrs)
    local i1,i2 = find(s, (chrs or "%s")..'*$')
    if i2 >= i1 then
        s = sub(s,1,i1-1)
    end
    return s
end

--- Split string by delimiter
--- @param str string
--- @param delim string
--- @param n number
--- @return table<string>
function utils.split(str, delim, n)
    local i1,ls, plain = 1,{}, true
    if not delim then
        delim = '%s+'
        plain = false
    end
    if delim == '' then
        return {str}
    end
    while true do
        local i2,i3 = find(str, delim, i1, plain)
        if not i2 then
            local last = sub(str, i1)
            if last ~= '' then insert(ls, last) end
            if #ls == 1 and ls[1] == '' then
                return {}
            else
                return ls
            end
        end
        insert(ls,sub(str,i1,i2-1))
        if n and #ls == n then
            ls[#ls] = sub(str, i1)
            return ls
        end
        i1 = i3 + 1
    end
end

--- Generate lua code for casting value to another type. Supported types:
---  number, string, table, iterator, boolean, boolean|any, any
--- @param value string lua code of the value
--- @param curr_type string current type of the value
--- @param to_type string required type
--- @return string lua code
function utils.cast_lua(value, curr_type, to_type)
    if curr_type == to_type or to_type == "any" then
        return value
    elseif to_type == "number" then
        return "__.n(" .. value .. ")"
    elseif to_type == "string" then
        return "__.s(" .. value .. ")"
    elseif to_type == "table" then
        if curr_type == "iterator" then
            return value
        else
            return "__.t(" .. value .. ")"
        end
    elseif to_type == "iterator" then
        if curr_type == "table" then
            return value
        else
            return "__.i(" .. value .. ")"
        end
    elseif to_type == "boolean" then
        return "__.b(" .. value .. ")"
    elseif to_type == "boolean|any" then
        if curr_type == "boolean" then
            return value
        else
            return "__.b2(" .. value .. ")"
        end
    else
        return value
    end
end

--- Numerate lines in the text
--- @param text string
--- @return string
function utils.numerate_lines(text, tab)
    tab = tab or ""
    local lines, i = {}, 1
    for _, s in ipairs(utils.split(text, "\n")) do
        insert(lines, tab .. format("%3d", i) .. "| " .. s)
        i = i + 1
    end
    return concat(lines, "\n")
end

if not utils.starts_with then
    --- Return True if input-string starts with prefix, otherwise return False.
    --- @param str string
    --- @param prefix string
    --- @param start number
    function utils.starts_with(str, prefix, start)
        start = start or 1
        return str:sub(start, start + #prefix -1) == prefix
        --return str:sub(start or 1, #prefix) == prefix
    end
end

return utils