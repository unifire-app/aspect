local tonumber = tonumber
local getmetatable = getmetatable
local type = type

local tests = {}

function tests.test_defined(__, v)
    return v ~= nil
end

function tests.tests_null(__, v)
    return v == nil
end

function tests.tests_nil(__, v)
    return v == nil
end

function tests.test_divisible_by(__, v, number)
    return tonumber(v) % number == 0
end

function tests.test_constant(__, v, const)
    return __.opts.consts[const] == v
end

function tests.test_empty(__, v)
    return not __.b(v)
end

function tests.test_iterable(__, v)
    local typ = type(v)
    if typ == "table" then
        return true
    elseif typ == "userdata" then
        return getmetatable(v) and getmetatable(v).__pairs ~= nil
    else
        return false
    end
end

function tests.test_even(__, v)
    return tonumber(v) % 2 == 0
end

function tests.test_odd(__, v)
    return tonumber(v) % 2 == 1
end

function tests.same_as(__, v1, v2)
    return v1 == v2
end

return tests