local tonumber = tonumber
local getmetatable = getmetatable
local type = type

local tests = {
    args = {
        divisible = "by",
        constant = true,
        same = "as"
    },
    fn = {}
}

function tests.fn.is_defined(__, v)
    return v ~= nil
end

function tests.fn.is_null(__, v)
    return v == nil
end

function tests.fn.is_nil(__, v)
    return v == nil
end

function tests.fn.is_divisible_by(__, v, number)
    return tonumber(v) % tonumber(number) == 0
end

function tests.fn.is_constant(__, v, const)
    return __.opts.consts[const] == v
end

function tests.fn.is_empty(__, v)
    return not __.b(v)
end

function tests.fn.is_iterable(__, v)
    local typ = type(v)
    if typ == "table" then
        return true
    elseif typ == "userdata" then
        return getmetatable(v) and getmetatable(v).__pairs ~= nil
    else
        return false
    end
end

function tests.fn.is_even(__, v)
    return (tonumber(v) % 2) == 0
end

function tests.fn.is_odd(__, v)
    return (tonumber(v) % 2) == 1
end

function tests.fn.is_same_as(__, v1, v2)
    return v1 == v2
end

return tests