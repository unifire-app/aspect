local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local type = type
local concat = table.concat
local insert = table.insert
local str_rep  = string.rep
local sub = string.sub
local find = string.find
local getmetatable = getmetatable
local tablex = require("pl.tablex")

local utils = {
    nkeys = table.nkeys or tablex.size
}

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

--- Outputs values to the stderr
function utils.var_dump(...)
    io.stderr:write(utils.dump(...) .. "\n" .. debug.traceback() .. "\n")
end

--- Export arguments as string
--- @return string
function utils.dump(...)
    local output = {};
    for _, v in pairs({ ... }) do
        if type(v) == 'table' then
            insert(output, utils.table_export(v, 0, {[tostring(v)] = true}))
        else
            insert(output, tostring(v))
        end
    end
    return concat(output, "\n")
end

--- Serialize the table
--- @param tbl table
--- @param indent number отступ в количествах пробелов
--- @return string
function utils.table_export(tbl, indent, tables)
    if not indent then
        indent = 0
    elseif indent > 16 then
        return "*** too deep ***"
    end
    local output = "";
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
            local table_id = tostring(v)
            if tables[table_id] then
                output = output .. formatting .. "*** recursive ***\n"
            elseif type(k) == "string" and k:sub(1, 1) == "_" then
                output = output .. formatting .. "*** private table ***\n"
            else
                tables[table_id] = true
                output = output .. formatting .. utils.table_export(v, indent + 1, tables) .. "\n"
            end
        else
            output = output .. formatting .. "("..type(v)..") " .. tostring(v) .. "\n"
        end
    end

    if output ~= "" then
        return "{\n" .. output ..  str_rep("  ", indent) .. "}"
    else
        return "{}"
    end
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

return utils