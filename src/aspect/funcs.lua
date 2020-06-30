local unpack = unpack or table.unpack
local concat = table.concat
local err = require("aspect.error")
local compiler_error = err.compiler_error
local runtime_error = err.runtime_error
local config = require("aspect.config")
local tags = require("aspect.tags")
local tag_type = config.compiler.tag_type
local dump = require("aspect.utils").dump
local quote_string = require("aspect.utils").quote_string
local strip = require("aspect.utils").strip
local date = require("aspect.date")
local utils = require("aspect.utils")
local range = require("aspect.utils.range")
local pairs = pairs
local ipairs = ipairs

local func = {
    args = {},
    fn = {},
    parsers = {}
}

--- Add function
--- @param name string
--- @param info table
--- @param fn fun(...):any
function func.add(name, info, fn)
    func.args[name] = info.args
    func.fn[name] = fn
    func.parsers[name] = info.parser
end

--- @param __ aspect.output
--- @param name string
--- @param context table
local function parent(__, name, context)
    local block

    if __.blocks[name] then
        for i = __.blocks[name].i + 1, #__.views do
            block = __.views[i].blocks[name]
            if block then
                break
            end
        end
    else
        return nil
    end

    if context then
        if block then
            block(__, context)
        end
    elseif block then
        return true
    end
end

--- Function {{ parent() }}
func.add('parent', {
    args = {},
    --- @param compiler aspect.compiler
    parser = function(compiler)
        local tag = compiler:get_last_tag("block")
        if not tag then
            compiler_error(nil, "syntax", "{{ parent() }} should be called in the {% block %}")
        else
            tag.parent = true
        end
        if compiler.tag_type == tag_type.EXPRESSION then -- {{ parent(...) }}
            local vars = utils.implode_hashes(compiler:get_local_vars())
            if vars then
                return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', __.setmetatable({ ' .. vars .. '}, { __index = _context }))' ;
            else
                return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', _context)' ;
            end
        else -- {% if parent(...) %}
            return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', nil)' ;
        end
    end
}, parent)

--- @param __ aspect.output
--- @param name string
--- @param template string|nil
local function block(__, context, name, template)
    local f
    if template then
        local view = __:get_view(template)
        if view.blocks[name] then
            f = view.blocks[name]
        end
    elseif __.blocks[name] then
        f = __.blocks[name].f
    end
    if context then
        if f then
            f(__, context)
        else
            runtime_error(__, "block " .. name .. " not found")
        end
    else
        return f ~= nil
    end
end

--- Function {{ block(name, [template]) }}
func.add('block', {
    args = {
        [1] = {name = "name", type = "string"},
        [2] = {name = "template", type = "string"},
    },
    --- @param compiler aspect.compiler
    --- @param args table
    parser = function(compiler, args)
        if not args.name then
            compiler_error(nil, "syntax", "function block() requires argument 'name'")
        end
        if compiler.tag_type == tag_type.EXPRESSION then -- {{ block(...) }}
            local vars, context = utils.implode_hashes(compiler:get_local_vars()), "_context"
            if vars then
                context =  '__.setmetatable({ ' .. vars .. ' }, { __index = _context })' ;
            end
            return '__.fn.block(__, ' .. context .. ', ' .. args.name .. ', ' .. (args.template or 'nil') .. ')', false
        else -- {% if block(...) %}
            return '__.fn.block(__, nil, ' .. args.name .. ', ' .. (args.template or 'nil') .. ')'
        end
    end
}, block)

--- Function {{ include(name, [vars], [ignore_missing], [with_context]) }}
func.add('include', {
    args = {
        [1] = {name = "name", type = "any"},
        [2] = {name = "vars", type = "table"},
        [3] = {name = "ignore_missing", type = "boolean"},
        [4] = {name = "with_context", type = "boolean"},
    },
    --- @param compiler aspect.compiler
    --- @param args table
    parser = function (compiler, args)
        if compiler.tag_type == tag_type.EXPRESSION then
            args.with_vars = true
            return tags.include(compiler, args)
        else
            return '__.fn.include(__, ' .. args.name .. ', true, nil)'
        end
    end
}, function (__, names, ignore, context)
    local view, error = __.opts.get(names)
    if not context then
        return view ~= nil
    end
    if error then
        runtime_error(__, error)
    elseif not view then
        if not ignore then
            runtime_error(__, "Template(s) not found. Trying " .. utils.join(names, ", "))
        else
            return
        end
    end
    view.body(__, context)
end)

--- Function {{ range(from, to, step) }}
func.add('range', {
    args = {
        [1] = {name = "from", type = "number"},
        [2] = {name = "to", type = "number"},
        [3] = {name = "step", type = "number"},
    }
}, function (__, args)
    if not args.from then
        __:notice("range(): requires 'from' argument")
        return {}
    end
    if not args.to then
        __:notice("range(): requires 'to' argument")
        return {}
    end
    if not args.step or args.step == 0 then
        args.step = 1
    end
    if args.step > 0 and args.to < args.from then
        __:notice("range(): 'to' less than 'from' with positive step")
        return {}
    elseif args.step < 0 and args.to > args.from then
        __:notice("range(): 'to' great than 'from' with negative step")
        return {}
    end
    return range.new(args.from, args.to, args.step)
end)

func.add("import", {
    args = {}
}, function (__, from, names)
    if not from then
        runtime_error(__, "import(): requires 'from' argument")
    end
    local view, error = __.opts.get(from)
    if not view then
        runtime_error(__, error)
    end
    if names then
        local macros = {}
        for i = 1, #names do
            local macro =  view.macros[ names[i] ]
            if not macro then
                runtime_error(__, "import(): macro '".. names[i] .. "' doesn't exists in the template " .. view.name)
            end
            macros[#macros + 1] = macro
        end
        return unpack(macros)
    else
        return view.macros or {}
    end
end)

--- {{ date(date) }}
func.add("date", {
    args = {
        [1] = {name = "date", type = "any"}
    }
}, function (__, args)
    return date.new(args.date)
end)

--- {{ dump(...) }}
func.add("dump", {
    args = nil,
    --- @param compiler aspect.compiler
    --- @param _ nil
    --- @param tok aspect.tokenizer
    parser = function (compiler, _, tok)
        if tok:is(")") then
            return "__.fn.dump(__, nil, _context)"
        end
        local vars = {}
        while true do
            local from = tok:get_pos()
            local expr = compiler:parse_expression(tok)
            local name = tok:get_path_as_string(from, tok.i - 1)
            vars[#vars + 1] = "{name = " .. quote_string(strip(name)) .. ", value = " .. expr .. "}"
            if tok:is(")") then
                break
            end
            tok:require(","):next()
        end
        return "__.fn.dump(__, {" .. concat(vars, ",") .. "})"
    end
}, function (__, args, ctx)
    local out = {}
    if args then
        out[1] = "Dump values:"
        for _, v in ipairs(args) do
            out[#out + 1] = v.name .. ": " .. dump(v.value) .. "\n"
        end
    else
        out[1] = "Dump context:"
        for name, value in pairs(ctx) do
            out[#out + 1] = name .. ": " .. dump(value) .. "\n"
        end
    end
    out[#out + 1] = "\nStack:\n" .. __:get_callstack()
    return concat(out, "\n")
end)

return func