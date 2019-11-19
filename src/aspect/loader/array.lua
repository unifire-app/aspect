local setmetatable = setmetatable
--local var_dump = require("aspect.utils").var_dump

--- Array template loader
--- @class aspect.loader.array
local array_loader = {}
local mt = {
    __call = function(self, tpl, name)
        return self[name]
    end
}

function array_loader.new(list)
    return setmetatable(list or {}, mt)
end

return array_loader