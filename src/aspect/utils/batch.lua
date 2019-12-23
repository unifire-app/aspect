local output = require("aspect.output")
local type = type
local ceil = math.ceil
local getmetatable = getmetatable
local setmetatable = setmetatable
local tablex = require("pl.tablex")
local nkeys = require("aspect.utils")
--local count = table.nkeys or tablex.size
--if table.nkeys then -- new luajit function
--    count = table.nkeys
--end

local function __pairs(self)
    return function ()
        if not self.key and self.n > 0 then
            return nil
        end
        local l, c, v = {}, self.count
        self.n = self.n + 1
        self.key, v = self.iter(self.ctx, self.key)
        while self.key do
            l[self.key] = v
            c = c - 1
            if c == 0 then
                break
            end
            self.key, v = self.iter(self.ctx, self.key)
        end
        if c == self.count then
            return nil
        end
        return self.n, l
    end, self
end

local function __count(self)
    local typ = type(self.t)
    local mt = getmetatable(self.t)
    if typ == "table" then
        if mt and mt.__count then
            return ceil(mt.__count(self.t) / self.count)
        elseif mt and mt.__pairs then -- has custom iterator. we don't know how much elements will be
            return 0
        else
            return ceil(nkeys(self.t) / self.count)
        end
    elseif typ == "userdata" then
        if mt and mt.__count then
            return ceil(mt.__count(self.t) / self.count)
        end
    else
        return 0
    end
end

--- Iterator for batch filter
--- @class aspect.utils.batch
local batch = {}
local mt = {
    __index = batch,
    __pairs = __pairs,
    __count = __count
}

--- @param t table
--- @param cnt number
function batch.new(t, cnt)
    if cnt == 0 then
        return nil
    end
    local iter, ctx, key = output.iter(t)
    if not iter then
        return nil
    end
    return setmetatable({
        tbl = t,
        iter = iter,
        ctx = ctx,
        key = key,
        count = cnt,
        n = 0
    }, mt)
end

return batch