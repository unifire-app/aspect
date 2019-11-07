local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local type = type
local concat = table.concat
local insert = table.insert

local utils = {}



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

return utils