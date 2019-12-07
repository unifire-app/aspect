local setmetatable = setmetatable
local floor = math.floor
local abs = math.abs

local function iterator(self, k)
    local i = self.from + k * self.step
    if self.incr then
        if i > self.to then
            return nil, nil
        else
            return k + 1, i
        end
    else
        if i < self.to then
            return nil, nil
        else
            return k + 1, i
        end
    end
end

local function __pairs(self)
    return iterator, self, 0
end

local function __count(self)
    if self.incr then
        return floor(abs((self.to - self.from) / self.step)) + 1
    else
        return floor(abs((self.from - self.to) / self.step)) + 1
    end
end

--- @class aspect.utils.range
--- @field from number
--- @field to number
--- @field step number
--- @field incr boolean
local range = {}
local mt = {
    __index = range,
    __pairs = __pairs,
    __count = __count
}

function range.new(from, to, step)
    return setmetatable({
        incr = from < to,
        from = from,
        to = to,
        step = step,
    }, mt)
end


return range