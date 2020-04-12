local setmetatable = setmetatable
local floor = math.floor
local abs = math.abs

--- Range iterator
--- @class aspect.utils.range
--- @field from number
--- @field to number
--- @field step number
--- @field incr boolean
local range = {}

--- Magic function for {{ for }} tag
--- @return function iterator (see range.__iterate)
--- @return table context object
--- @return number initial key value
function range:__pairs()
    return self.__iterate, self, 0
end

--- Iterator
--- @return number the key
--- @return number the value
function range:__iterate(k)
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

--- Magic function for calculating the number of iterations (elements)
--- @return number count of iterations/elements
function range:__len()
    if self.incr then
        return floor(abs((self.to - self.from) / self.step)) + 1
    else
        return floor(abs((self.from - self.to) / self.step)) + 1
    end
end

local mt = {
    __index = range,
    __pairs = range.__pairs,
    __len = range.__len
}

--- Range constructor
--- @param from number
--- @param to number
--- @param step number
function range.new(from, to, step)
    return setmetatable({
        incr = from < to,
        from = from,
        to = to,
        step = step,
    }, mt)
end

return range