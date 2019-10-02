local jit = jit
local setfenv = setfenv
local type = type
local pcall = pcall
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local err = require("aspect.err")
local output = require("aspect.output")
local dump = require("pl.pretty").dump

--- @class aspect.render
--- @field name string
--- @field body function
--- @field blocks table of functions
--- @field macros table of functions
local render = {}
local mt = {__index = render}

function render.load(aspect, func)
    if type(func) == 'string' then
        func = nil
    end
    if type(func) ~= 'function' then
        return nil, err.new("loaded view is not a function/bytecode")
    end

    local context = { __index = function(t, k)
        return t._context[k]
    end }
    local view = func()
    local rend = setmetatable({
        aspect = aspect,
        name = view.name,
        deps = view.deps,
        body = view.body,
        blocks = {},
        macros = {},
        include = {}
    }, mt)
    setfenv(rend.body, setmetatable({}, context))
    for n, f in pairs(view.blocks) do
        setfenv(f, setmetatable({}, context))
        rend.blocks[n] = f
    end
    for n, f in pairs(view.macros) do
        setfenv(f, {})
        rend.macros[n] = f
    end

    return rend
end

--- Calls template and returns the result
--- @param vars table of the variable for template
--- @return string of the template result
--- @return aspect.error if error occur
function render:fetch(vars)
    local out, ok, error = output.new(), nil, nil
    ok, error = pcall(self.body, out, vars)
    if ok then
        return tostring(out)
    elseif type(error) == "table" then
        return nil,  err.new(error)
    else
        return nil, err.new({
            code = "runtime",
            name = self.name,
            message = tostring(error)
        })
    end
end

function render:pipeline(vars, callback, chunk_size)

end

function render:output(vars)

end

function render:has_block(block_name)
    return self.blocks[block_name] ~= nil
end

function render:fetch_block(block_name, vars)

end

function render:has_macro(macro_name)
    return self.macros[macro_name] ~= nil
end

--- Calls macro and returns the result
--- @param macro_name string the macro name
--- @param arguments table of arguments for macro
--- @return string macro result
--- @return aspect.error if error occur
function render:fetch_macro(macro_name, arguments)
    local out, ok, error = output.new(), nil, nil
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

return render