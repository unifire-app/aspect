local setmetatable = setmetatable
local compiler = require("aspect.compiler")
local output = require("aspect.output")
local funcs = require("aspect.funcs")
local filters = require("aspect.filters")
local tests = require("aspect.tests")
local err = require("aspect.error")
local utils = require("aspect.utils")
local var_dump = utils.var_dump
local loadcode
local loadchunk
local _VERSION = _VERSION
local loadstring = loadstring
local load = load
local setfenv = setfenv
local function_dump = string.dump
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local type = type
local pcall = pcall
local next = next
local jit = jit


--- View. Object representation of template.
--- @class aspect.view
--- @field v number view version
--- @field name string the template name
--- @field body function body function
--- @field macros table hashtable of the macros
--- @field blocks table<aspect.template.block> hashtable of the blocks
--- @field uses table<aspect.template.use> hashtable of {% use %} tags
--- @field extends string|boolean parent template if parent's name is string, or just true if name unknown (dynamically)

--- @class aspect.template.block
--- @field body fun(__: aspect.output, context: table) block's code
--- @field vars table used context variables
--- @field parent boolean use parent() function inside

--- @class aspect.template.use
--- @field name string the external template name
--- @field with table blocks map like { remote_name = "local_name", ... }

--- @class aspect.template
--- @field compiler aspect.compiler
--- @field stats boolean
--- @field cache boolean|table enable or disable in-memory cache. by default: false. set table (as container) for enable cache.
--- @field loader fun(name: string):string,string template source code loader with etag (optionally)
--- @field luacode_load fun(name: string, tpl: aspect.template):string
--- @field luacode_save fun(name: string, luacode: string, tpl: aspect.template)
--- @field bytecode_load fun(name: string, tpl: aspect.template):string
--- @field bytecode_save fun(name: string, bytecode: string, tpl: aspect.template)
local template = {
    _VERSION = "1.14",
    _NAME = "aspect",
}
local mt = { __index = template }

do
    if _VERSION == "Lua 5.1" then
        if jit then
            loadchunk = function(tpl, code, name)
                return load(code, name, nil, tpl.env)
            end
        else
            loadchunk = function(tpl, code, name)
                local func, error = loadstring(code, name)
                if func then
                    setfenv(func, tpl.env)
                end
                return func, error
            end
        end
    else
        loadchunk = function(tpl, code, name)
            return load(code, name, nil, tpl.env)
        end
    end
    --- @param tpl aspect.template
    --- @param code string
    --- @param name string the template name
    loadcode = function (tpl, code, name)
        local error
        if type(code) == 'string' then
            code, error = loadchunk(tpl, code, name .. ".lua")
            if error then
                return nil, err.new("Error loading '" .. name .. "' code: " .. tostring(error))
            end
        elseif type(code) ~= 'function' then
            return nil, err.new("loaded view '" .. name .. "' is not valid a function or bytecode")
        end
        return code(), nil, code
    end
end

--- @param options table
function template.new(options)
    options = options or {}
    local tpl = setmetatable({
        cache = false,
        compiler = compiler,
        loader = options.loader,
        env = options.env or {},
        luacode_load = options.luacode_load,
        luacode_save = options.luacode_save,
        bytecode_load = options.bytecode_load,
        bytecode_save = options.bytecode_save,
    }, mt)
    if options.cache then
        if options.cache == true then
            tpl.cache = {}
        else
            tpl.cache = options.cache
        end
    end
    tpl.opts = {
        escape = options.autoescape or false,
        strip = options.autostrip or false,
        stack_size = 20,
        f = filters.fn,
        fn = funcs.fn,
        t = tests.fn
    }
    tpl.stats = options.stats or true
    --- @param names table|string
    tpl.opts.get = function(names)
        local view, error
        if type(names) == "table" then
            for _, n in ipairs(names) do
                view, error = tpl:get_view(n)
                if error then
                    return nil, error
                elseif view then
                    return view
                end
            end
        else
            view, error = tpl:get_view(names)
            if error then
                return nil, error
            elseif view then
                return view
            end
        end
    end
    return tpl
end

--- Parse the template.
--- If `source` not nil then code will be parsed else source code will be loaded via loader by name.
--- @param name string the template name
--- @param source string|nil
--- @return aspect.compiler
--- @return aspect.error
function template:parse(name, source)
    local error, ok
    if not source then
        source, error = self.loader(name, self)
        if not source then
            return nil, nil, err.new(error)
        end
    end

    local cmp = self.compiler.new(self, name)
    ok, error = cmp:run(source)
    if not ok then
        return nil, error
    else
        return cmp
    end
end

--- Prepare the view (import blocks from {% use %} tags)
--- @param tpl aspect.template
--- @param view aspect.view
local function expand(tpl, view)
    -- lazy load {% use %} tags
    if view.uses then
        for _, use in ipairs(view.uses) do
            local use_view, use_error = tpl:get_view(use.name)
            if use_view then -- use template loaded
                if next(use_view) then -- loaded template has blocks
                    if use.with then -- we use peace of blocks
                        for n, a in pairs(use.with) do
                            if not view.blocks[a] and use_view.blocks[n] then
                                view.blocks[a] = use_view.blocks[n]
                            end
                        end
                    else
                        for n, b in pairs(use_view.blocks) do
                            if not view.blocks[n] then
                                view.blocks[n] = b
                            end
                        end
                    end
                end
            elseif use_error then
                return err.new("Failed to load block from template " .. view.name .. ": "
                    .. err.new(use_error):get_message()):set_name(view.name, use_view and use_view.line or nil)
            end
        end
    end
end

--- Parse, compile and prepare the template.
--- If `source` not nil then code will be compiled else source code will be loaded via loader by name.
--- If `aspect.error` and `aspect.compiler` is nil — the template not found
--- @param name string
--- @param source string
--- @param cache boolean save into cache
--- @return aspect.error if error occurred
--- @return aspect.compiler
--- @return aspect.view result view
--- @return function view as function for dumping to bytecode
function template:compile(name, source, cache)
    local ok, error, code, func, view
    if not source then
        source, error = self.loader(name, self)
        if not source then
            if error then
                return err.new(error, "compile"), nil, nil, nil
            else
                return nil
            end
        end
    end

    local build = self.compiler.new(self, name)
    ok, error = build:run(source)

    if not ok then
        return error, build, nil, nil
    end
    code = build:get_code()
    func, error = loadchunk(self, code, name .. ".lua")
    if error then
        return nil, err.new("Error loading '" .. name .. "' code: " .. tostring(error))
    end

    view, error = loadcode(self, code, name)
    if not view then
        return error, build, nil, nil
    end
    error = expand(self, view)
    if error then
        return error, build, view, func
    end
    if self.cache and cache then
        self.cache[view.name] = view
    end

    return nil, build, view, func
end

--- Returns the view
--- @param name string the view name
--- @param source string the source code
--- @return aspect.view|nil
--- @return aspect.error|nil
--- @return aspect.compiler|nil
function template:get_view(name)
    if self.cache and self.cache[name] then
        return self.cache[name]
    end
    return self:load(name)
end

--- Load template and compile template if needed.
--- This method works without internal template cache.
--- @param name string the view name
--- @return aspect.view|nil
--- @return aspect.error or nil if OK
--- @return aspect.compiler or nil of the template from cache
function template:load(name)
    local bytecode, luacode, build, error, f, view
    if self.bytecode_load then
        bytecode, error = self.bytecode_load(name, self)
        if bytecode then
            view = loadcode(self, bytecode, name)
        elseif error then
            return nil, err.new(error)
        end
    end
    if not view and self.luacode_load then
        luacode, error = self.luacode_load(name, self)
        if luacode then
            view, error, f = loadcode(self, luacode, name)
            if error then
                return nil, error
            end
            if self.bytecode_save then
                self.bytecode_save(name, function_dump(f), self)
            end
        elseif error then
            return nil, err.new(error)
        end
    end
    if view then
        error = expand(self, view)
        if error then
            return nil, error
        end
        if self.cache then
            self.cache[view.name] = view
        end
        return view
    end
    error, build, view, f = self:compile(name)
    if error then
        return nil, error, build
    elseif not view then
        return nil
    end

    if self.luacode_save then
        self.luacode_save(name, build:get_code(), self)
    end
    if self.bytecode_save then
        self.bytecode_save(name, function_dump(f), self)
    end

    return view, nil, build
end

--- @param name string
--- @param source string
--- @param vars table
--- @param options table|nil
--- @overload fun(source:string, vars:table, name:string)
--- @overload fun(source:string, vars:table)
function template:eval(source, vars, options, name)
    local error, build, view = self:compile(name or "eval", source, name)
    if error then
        return nil, error, build
    end
    return self:render_view(view, vars, options)
end

--- @param view aspect.view
--- @param vars table
--- @param options table
function template:render_view(view, vars, options)
    local out, ok, error = output.new(self.opts, vars, options or {}), nil, nil
    out:push_view(view)
    while view.extends do
        local extends = view.extends
        if extends == true then -- dynamic extends
            ok, extends = pcall(view.body, out, vars)
            if not ok then
                if err.is(extends) then
                    return out, extends
                else
                    return out, err.new({
                        code = "runtime",
                        name = view.name,
                        line = out.line,
                        message = tostring(extends)
                    })
                end
            end
        end
        local v, e = self:get_view(extends)
        if not v then
            return nil, err.new(e or "Template '" .. tostring(view.extends) .. "' not found while extending " .. name)
        end
        view = v
        out:push_view(view)
    end
    ok, error = pcall(view.body, out, vars)
    if ok then
        return out:finish()
    elseif err.is(error) then
        return out:finish(), error
    else
        return out:finish(), err.new({
            code = "runtime",
            name = view.name,
            line = out.line,
            message = tostring(error)
        })
    end
end

--- Returns template result as string
--- @param name string the template name
--- @param vars table
--- @return aspect.output template result
--- @return aspect.error if error occur
function template:render(name, vars, options)
    local view, error = self:get_view(name)
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    return self:render_view(view, vars, options)
end

--- Returns macro result as string
--- @param name string the template name
--- @param macro_name string the macro name
--- @param arguments table of arguments for macro
--- @return aspect.output macro result
--- @return aspect.error if error occur
function template:render_macro(name, macro_name, arguments)
    local out, ok = output.new(self.opts, arguments, {}), nil
    local view, error = self:get_view(name)
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    if view.macros[macro_name] then
        ok, error = pcall(view.macros[macro_name], out, arguments)
        if ok then
            return tostring(out)
        else
            return out:finish(), err.runtime_error(out, error)
        end
    else
        return out:finish(), err.new({
            name = view.name,
            message = "Macro '" .. macro_name .. "' not found"
        })
    end
end

--- Returns block result as string
--- @param name string the template name
--- @param block_name string the block name
--- @param vars table of arguments for block
--- @return aspect.output block result
--- @return aspect.error if error occur
function template:render_block(name, block_name, vars)
    local out, ok = output.new(self.opts, vars, {}), nil
    local view, error = self:get_view(name)
    if not view then
        return nil, err.new(error or "Template '" .. tostring(name) .. "' not found")
    end
    if view.blocks and view.blocks[block_name] then
        ok, error = pcall(view.blocks[block_name], out, vars)
        if ok then
            return tostring(out)
        else
            return out:finish(), err.runtime_error(out, error)
        end
    else
        return out:finish(), err.new{
            name = name,
            message = "Block '" .. block_name .. "' not found"
        }
    end
end

--- Print template result
--- @param name string|table
--- @param vars table
--- @param chunk_size number
--- @return aspect.output
function template:display(name, vars, chunk_size)
    return self:render(name, vars, {
        chunk_size = chunk_size,
        print = true
    })
end

--- The generated data from the template is sent in the reverse order as it is generated.
--- @param name string|table
--- @param vars table
--- @param callback fun(out:aspect.output, chunk:string)
--- @param chunk_size number
--- @return aspect.output
function template:generate(name, vars, callback, chunk_size)
    return self:render(name, vars, {
        chunk_size = chunk_size,
        print = callback
    })
end

return template