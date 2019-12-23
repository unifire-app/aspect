local setmetatable = setmetatable

--- Array template loader
--- @class aspect.loader.array
local array_loader = {}
local mt = {
    __call = function(self, name)
        return self[name]
    end
}

function array_loader.new(list)
    return setmetatable(list or {}, mt)
end

return array_loader