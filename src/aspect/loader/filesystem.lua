local setmetatable = setmetatable
local open = io.open

--- Filesystem template loader
--- @class aspect.loader.filesystem
local fs_loader = {}
local mt = {
    __call = function(self, name)
        local file = open(self.path .. "/" .. name, "rb")
        if not file then
            return nil
        end
        local content = file:read("*a")
        file:close()
        return content
    end
}

function fs_loader.new(path)
    return setmetatable({
        path = path
    }, mt)
end

return fs_loader