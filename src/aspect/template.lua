local setmetatable = setmetatable
local compiler = require("aspect.compiler")
local output = require("aspect.output")
local filters = require("aspect.filters")
local err = require("aspect.err")
local loadcode
local loadstring = loadstring
local dump = string.dump
local tostring = tostring
local assert = assert
local ipairs = ipairs
local type = type
local pcall = pcall
local setfenv = setfenv
local ngx = ngx
local jit = jit
local var

local _VERSION = _VERSION

--- @class aspect.provider
--- @field load function(aspect.provider p, string name):string,tag template source code loader
--- @field luacode_load function(aspect.provider p, string name):string
--- @field luacode_save function(aspect.provider p, aspect.view view)
--- @field bytecode_load function(aspect.provider p, string name):string
--- @field bytecode_save function(aspect.provider p, aspect.view view)

--- @class aspect.template
--- @field compiler aspect.compiler
--- @field provider aspect.provider
--- @field loader function (string name) template source code loader
--- @field bytecode_loader function (string name) Returns raw byte code
--- @field bytecode_dumper function (string bytecode) Returns raw byte code
local template = {
    _VERSION = "0.1"
}
local mt = {__index = template}

do
    local context = { __index = function(t, k)
        return t._context[k]
    end }
    loadcode = function (func, name)
        local error
        if type(func) == 'string' then
            func, error = loadstring(func, name)
            if error then
                return nil, err.new("Failed to load '" .. name .. "': " .. tostring(error))
            end
        end
        if type(func) ~= 'function' then
            return nil, err.new("loaded view '" .. name .. "' is not a function/bytecode")
        end
        local view = func()
        setfenv(view.body, setmetatable({}, context))
        for _, b in ipairs(view.blocks) do
            setfenv(b, setmetatable({}, context))
        end
        for _, m in ipairs(view.macros) do
            setfenv(m, {})
        end
        return view
    end
end
function template.new(options)
    local tpl = setmetatable({
        cache = false,
        compiler = compiler,
        loader = nil,
        cacher = nil,
        filters = {},
        filters_args = {},
    }, mt)
    tpl.opts = {
        escape = false,
        strip = false,
        stack_size = 20,
        f = setmetatable(filters, { __index = function (v) return v end})
    }
    --- @param names table|string
    tpl.opts.get = function(names)
        local view, error
        if type(names) == "table" then
            for _, n in ipairs(names) do
                view, error = tpl:get_view(n)
                if error then
                    return error
                elseif view then
                    return view
                end
            end
        else
            view, error = tpl:get_view(names)
            if error then
                return error
            elseif view then
                return view
            end
        end
    end
    return tpl
end

--- @param name string
--- @param source string
--- @return aspect.compiler
function template:compile_code(name, source)
    local tpl = self.compiler.new(self, name)
    local ok, error = tpl:run(source)
    if not ok then
        return nil, error
    else
        return tpl
    end
end



--- Returns the view
--- @param name string the view name
--- @return aspect.render
--- @return aspect.error
function template:get_view(name)
    if self.cache and self.cache[name] then
        return self.cache[name]
    end
    local view, error = self:load(name)
    if self.cache and view then
        self.cache[name] = view
    end
    if not view and error then
        return nil, err.new(error)
    end
    return view
end

--- Load template and compile template if needed.
--- This method works without internal template cache.
--- @param name string the view name
--- @return aspect.render
--- @return aspect.error
function template:load(name)
    local bytecode, luacode, source, build, ok, error, func
    if self.cacher and self.cacher.binary_load then
        bytecode, error = self.cacher:binary_load(name)
        if bytecode then
            return loadcode(bytecode, name .. ".lua")
        elseif error then
            return err.new(error)
        end
    end
    if self.cacher and self.cacher.luacode_load then
        luacode, error = self.cacher:luacode_loader(name)
        if luacode then
            return loadcode(luacode, name .. ".lua")
        end
    end
    source, error = self:loader(name)
    if source then
        build = self.compiler.new(self, name)
        ok, error = build:run(source)
        if ok then
            luacode = build:get_code()
            if self.cacher and self.cacher.luacode_save then
                self.cacher:luacode_save(name, luacode)
            end
            print(luacode)
            if self.cacher and self.cacher.binary_save then
                func, error = loadstring(luacode, name .. ".lua")
                if not func then
                    return nil, err.new(error)
                end
                self.cacher:binary_save(name, dump(func))
            end
            return loadcode(luacode, name .. ".lua")
        else
            return nil, error
        end
    elseif error then
        return nil, err.new(error)
    else
        return nil
    end
end

--- Add filter
function template:add_filter(name, func, args_list)
    self.filters[name] = func
    self.filters_about[name] = args_list
end

--- Returns template result as string
--- @param name string
--- @param vars table
function template:fetch(name, vars)
    local view, error = self:get_view(name)
    local out, ok = output.new(name, nil, nil, self.opts), nil
    if not view then
        return nil, err.new(error)
    end
    ok, error = pcall(view.body, out, vars)
    if ok then
        return tostring(out)
    elseif err.is(error) then
        return nil, error
    else
        return nil, err.new({
            code = "runtime",
            name = view.name,
            line = out.line,
            message = tostring(error)
        })
    end
end

--- @param name string the template name
--- @param macro_name string the macro name
--- @param arguments table of arguments for macro
--- @return string macro result
--- @return aspect.error if error occur
function template:fetch_macro(name, macro_name, arguments)
    local out, ok = output.new(), nil
    local view, error = self:get_view(name)
    if not view then
        return err.new(error)
    end
    macro_name = tostring(macro_name)
    if self.macros[macro_name] then
        ok, error = pcall(self.macros[macro_name], out, arguments)
        if ok then
            return tostring(out)
        elseif type(error) == "table" then
            return nil,  err.new(error)
        else
            return nil, err.new({
                code = "runtime",
                name = self.name,
                line = output.line,
                message = "Macro '" .. macro_name .. "' errored: " .. tostring(error)
            })
        end
    else
        return nil, err.new({
            name = self.name,
            message = "Macro '" .. macro_name .. "' doesn't exists"
        })
    end
end

return template