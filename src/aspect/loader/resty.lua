local setmetatable = setmetatable
local capture = ngx.location.capture

--- Ngx+lua (resty) template loader
--- @class aspect.loader.resty
local resty_loader = {}
local mt = {
    __call = function(self, name)
        local res = capture(self.url .. name, {
            method = "GET"
        })
        if res and res.status == 200 then
            return res.body
        end
        return nil
    end
}

--- @param url string the URL prefix (for example /.templates/)
function resty_loader.new(url)
    return setmetatable({
        url = url
    }, mt)
end

return resty_loader