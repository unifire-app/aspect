local setmetatable = setmetatable
local compiler = require("aspect.compiler")
local render = require("aspect.render")
local loadchunk
local loadstring = loadstring
local assert = assert
local load = load
local setfenv = setfenv
local ngx = ngx
local jit = jit
local var

local _VERSION = _VERSION

--- @class aspect.template
--- @field compiler aspect.compiler
--- @field loader function (string name) template source code loader
--- @field bytecode_loader function (string name) Returns raw byte code
--- @field bytecode_dumper function (string bytecode) Returns raw byte code
local template = {
    _VERSION = "0.1"
}
local mt = {__index = template}

function template.new()
    local tpl = setmetatable({
        cache = {},
        compiler = compiler,
        loader = nil,
        batch_loader = nil,
        bytecode_loader = nil,
        bytecode_dumper = nil,
        luacode_loader = nil,
        luacode_dumper = nil,
        tpls = {},
        filters = {},
        filters_args = {},
        getter = nil,
        is_iteratable = function (v) if v.iterator  then return true else return false end end
    }, mt)
    local ctx = {}
    local context = { __index = function(t, k)
        return t.context[k] or t.tpl[k]
    end }
    if _VERSION == "Lua 5.1" then

        if jit then
            tpl.loadchunk = function(tp, view)
                return assert(load(view, nil, nil, setmetatable(ctx, context)))
            end
        else
            tpl.loadchunk = function(tp, view)
                local func = assert(loadstring(view))
                setfenv(func, setmetatable(ctx, context))
                return func
            end
        end
    else
        tpl.loadchunk = function(tp, view)
            return assert(load(view, nil, nil, setmetatable(ctx, context)))
        end
    end
    return tpl
end

--- @param name string
--- @param source string
--- @return aspect.compiler
function template:compile_code(name, source)
    local tpl = self.compiler.new(self, name)
    local ok, err = tpl:run(source)
    if not ok then
        return nil, err
    else
        return tpl
    end
end

--- Returns the view
--- @param name string the view name
--- @return aspect.render
--- @return aspect.error
function template:get(name)
    if self.cache and self.cache[name] then
        return self.cache[name]
    end
    local view, err = self:load(name)
    if view and self.cache then
        self.cache[name] = view
    end
    return view, err
end

--- Load template and compile template if needed.
--- This method works without internal template cache.
--- @param name string the view name
--- @return aspect.render
--- @return aspect.error
function template:load(name)
    local bytecode, luacode, source, build, ok, err
    if self.bytecode_loader then
        bytecode = self:bytecode_loader(name)
        if bytecode then
            return render.load(self, bytecode)
        end
    end
    if self.luacode_loader then
        luacode = self:luacode_loader(name)
        if luacode then
            return render.load(self, luacode)
        end
    end
    source, err = self:loader(name)
    if source then
        build = self.compiler.new(self, name)
        ok, err = build:run(source)
        if ok then
            if self.luacode_dumper then
                self:luacode_dumper(name, build:get_code())
            end
            print(build:get_code())
            local func = loadstring(build:get_code(), name .. ".lua")
            if self.bytecode_dumper then
                self:bytecode_dumper(name, string.dump(func))
            end
            return render.load(self, func)
        else
            return nil, err
        end
    else
        return nil, err
    end
end

--- Add filter
function template:add_filter(name, func, args_list)
    self.filters[name] = func
    self.filters_about[name] = args_list
end

return template