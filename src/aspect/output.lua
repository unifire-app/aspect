local concat = table.concat
local setmetatable = setmetatable
local print = print
local type = type
local ipairs = ipairs
local next = next
local tostring = tostring
local gsub = string.gsub
local ngx_null
local cjson_null
local cbson_null
local yaml_null
local ngx = ngx or {}

do
    if ngx.null then
        ngx_null = ngx.null
    end

    local has_cjson, cjson = pcall(require, "cjson.safe")
    if has_cjson then
        cjson_null = cjson.null
    end

    local has_cbson, cbson = pcall(require, "cbson")
    if has_cbson then
        cbson_null = cbson.null()
    end

    local has_yaml, yaml = pcall(require, "yaml")
    if has_yaml then
        yaml_null = yaml.NULL
    end
end

--- Output handler
--- @class aspect.output
--- @field data table output fragments
local output = {}

local function __call_collect(self, arg)
    self.data[#self.data + 1] = arg
end

local function __call_chunked(self, arg)

end

local function __tostring(self)
    return concat(self.data)
end

local mt_collect = {
    __call = __call_collect,
    __tostring = __tostring,
    __index = output
}

local mt_print  = {
    __call = ngx.print or print,
    __tostring = __tostring,
    __index = output
}


function output.new(p, size, opts)
    return setmetatable({
        line = 0,
        data = {},
        p = p,
        size = size,
        escape = opts and (opts.escape or false),
        strip = opts and (opts.strip or false),
        filters = opts and (opts.filters or {})
    }, mt_collect)
end

--- Cast value to boolean
--- @param v any
--- @return boolean
function output.b(v)
    if v == nil or v == false or v == "" or v == 0  then
        return false
    else
        local t = type(v)
        if t == "table" then
            if t.__toboolean then
                t:__toboolean()
            elseif next(v) == nil then
                return false
            end
        elseif t == "userdata" and (v == cjson_null or v == cbson_null or v == yaml_null or v == ngx_null) then
            return false
        end
        return true
    end
end

--- Cast value to string
--- @param v any
--- @return string
function output.s(v)
    if v == nil or v == cjson_null or v == cbson_null or v == yaml_null or v == ngx_null then
        return ""
    else
        return tostring(v)
    end
end

--- @param v any
--- @param ... string
function output.v(v, ...)
    for _, k in ipairs({...}) do
        if type(v) ~= "table" then
            return nil
        end
        if v[k] ~= nil then
            v = v[k]
        end
    end
    return v
end

function output:e(v)
    if self.escape then
        return self(gsub(v, "[}{\">/<'&]", {
            ["&"] = "&amp;",
            ["<"] = "&lt;",
            [">"] = "&gt;",
            ['"'] = "&quot;",
            ["'"] = "&#39;",
            ["/"] = "&#47;"
        }))
    else
        return self(v)
    end
end

return output