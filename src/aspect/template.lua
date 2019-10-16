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
local pairs = pairs
local ipairs = ipairs
local type = type
local pcall = pcall
local setfenv = setfenv
local ngx = ngx
local jit = jit
local var

local _VERSION = _VERSION

--- View
--- @class aspect.view
--- @field name string
--- @field body fun
--- @field macros table<fun>
--- @field blocks table<fun>
--- @field vars table<string>
--- @field uses table<string>
--- @field extends string|fun
--- @field cached string (dynamic)
--- @field has_blocs boolean (dynamic)
--- @field has_macros boolean (dynamic)
local _view = {}

--- @class aspect.provider
--- @field load function(aspect.provider p, string name):string,tag template source code loader
--- @field luacode_load function(aspect.provider p, string name):string
--- @field luacode_save function(aspect.provider p, aspect.view view)
--- @field bytecode_load function(aspect.provider p, string name):string
--- @field bytecode_save function(aspect.provider p, aspect.view view)
local _cacher = {}

--- @class aspect.template
--- @field compiler aspect.compiler
--- @field provider aspect.provider
--- @field loader function (string name) template source code loader
--- @field bytecode_loader function (string name) Returns raw byte code
--- @field bytecode_dumper function (string bytecode) Returns raw byte code
local template = {
    _VERSION = "0.1"
}
local mt = { __index = template }

do
    local context = { __index = function(t, k)
        return t._context[k]
    end }
    --- @param t aspect.template
    --- @param func fun
    --- @param name string
    loadcode = function (t, func, name)
        local error, c = nil, 0
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
        for _, b in pairs(view.blocks) do
            c = c + 1
            setfenv(b, setmetatable({}, context))
        end
        if c > 0 then
            view.has_blocks = true
        end
        c = 0
        for _, m in pairs(view.macros) do
            c = c + 1
            setfenv(m, {})
        end
        if c > 0 then
            view.has_macros = true
        end
        return view
    end
end

--- @param options table
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
        f = setmetatable(filters, { __index = function (v) return v end })
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
--- @return aspect.view|nil
--- @return aspect.error|nil
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
--- @return aspect.view|nil
--- @return aspect.error|nil
function template:load(name)
    local bytecode, luacode, source, build, ok, error, func
    if self.cacher and self.cacher.binary_load then
        bytecode, error = self.cacher:binary_load(name)
        if bytecode then
            return loadcode(self, bytecode, name .. ".lua")
        elseif error then
            return nil, err.new(error)
        end
    end
    if self.cacher and self.cacher.luacode_load then
        luacode, error = self.cacher:luacode_loader(name)
        if luacode then
            return loadcode(self, luacode, name .. ".lua")
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
            return loadcode(self, luacode, name .. ".lua")
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
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    local out, ok = output.new(self.opts), nil
    out:add_blocks(view)
    while view.extends do
        if view.extends == true then -- dynamic extends
        else -- static extends
            view, error = self:get_view(view.extends)
            if not view then
                return nil, err.new(error or "Template '" .. view.extends .. "' not found while extending " .. name)
            end
        end
        out:add_blocks(view)
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

--- Returns macro result as string
--- @param name string the template name
--- @param macro_name string the macro name
--- @param arguments table of arguments for macro
--- @return string macro result
--- @return aspect.error if error occur
function template:fetch_macro(name, macro_name, arguments)
    local out, ok = output.new(self.opts, name), nil
    local view, error = self:get_view(name)
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    if view.macros[macro_name] then
        ok, error = pcall(view.macros[macro_name], out, arguments)
        if ok then
            return tostring(out)
        else
            return nil, err.runtime_error(out, error)
        end
    else
        return nil, err.new({
            name = view.name,
            message = "Macro '" .. macro_name .. "' not found"
        })
    end
end

--- Returns block result as string
--- @param name string the template name
--- @param block_name string the block name
--- @param vars table of arguments for block
--- @return string block result
--- @return aspect.error if error occur
function template:fetch_block(name, block_name, vars)
    local out, ok = output.new(self.opts, name), nil
    local view, error = self:get_view(name)
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    if view.blocks and view.blocks[block_name] then
        ok, error = pcall(view.blocks[block_name], out, vars)
        if ok then
            return tostring(out)
        else
            return nil, err.runtime_error(out, error, "In the " .. view.name .. " an error occurred: ")
        end
    else
        return nil, err.new{
            name = name,
            message = "Block '" .. block_name .. "' not found"
        }
    end
end

return template