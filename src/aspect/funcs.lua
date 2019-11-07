local unpack = unpack
local concat = table.concat
local err = require("aspect.err")
local compiler_error = err.compiler_error
local runtime_error = err.runtime_error
local quote_string = require("pl.stringx").quote_string
local config = require("aspect.config")
local tags = require("aspect.tags")
local tag_type = config.compiler.tag_type
local dump = require("aspect.utils").dump
local date = require("date")


local function join(t, delim)
    if type(t) == "table" then
        return table.concat(t, delim)
    else
        return tostring(t)
    end
end

local func = {
    args = {},
    fn = {},
    parsers = {}
}

--- Args of {% parent() %}
func.args.parent = {}

--- {% parent() %}
--- @param compiler aspect.compiler
function func.parsers.parent(compiler)
    local tag = compiler:get_last_tag("block")
    if not tag then
        compiler_error(nil, "syntax", "{{ parent() }} should be called in the {% block %}")
    else
        tag.parent = true
    end
    if compiler.tag_type == tag_type.EXPRESSION then -- {{ parent(...) }}
        local vars = compiler.utils.implode_hashes(compiler:get_local_vars())
        if vars then
            return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', __.setmetatable({ ' .. vars .. '}, { __index = _context }))' ;
        else
            return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', _context)' ;
        end
    else -- {% if parent(...) %}
        return '__.fn.parent(__, ' .. quote_string(tag.block_name) .. ', nil)' ;
    end
end

--- @param __ aspect.output
--- @param name string
--- @param context table|nil
function func.fn.parent(__, name, context)
    local block
    if __.parents and __.parents[name] then
        local parents = __.parents[name]
        if parents.list and parents.list[parents.pos] then
            block = parents.list[parents.pos]
            parents.pos = parents.pos + 1
        end
    else
        return nil
    end

    if context then
        if block then
            block.body(__, context)
        end
    elseif block then
        return true
    end
end

--- Args of {% block(name, template) %}
func.args.block = {"name", "template"}

--- {% block(name[, template]) %}
--- @param compiler aspect.compiler
--- @param args table
function func.parsers.block(compiler, args)
    if not args.name then
        compiler_error(nil, "syntax", "function block() requires argument 'name'")
    end
    if compiler.tag_type == tag_type.EXPRESSION then -- {{ block(...) }}
        local vars, context = compiler.utils.implode_hashes(compiler:get_local_vars()), "_context"
        if vars then
            context =  '__.setmetatable({ ' .. vars .. ' }, { __index = _context })' ;
        end
        return '__.fn.block(__, ' .. context .. ', ' .. args.name .. ', ' .. (args.template or 'nil') .. ')', false
    else -- {% if block(...) %}
        return '__.fn.block(__, nil, ' .. args.name .. ', ' .. (args.template or 'nil') .. ')'
    end
end

--- @param __ aspect.output
--- @param context table|nil if nil - check condition: {% if block(...) %}
--- @param name string
--- @param template string|nil
function func.fn.block(__, context, name, template)
    local block
    if template then
        local view = __:get_view(template)
        if view.blocks[name] then
            block = view.blocks[name]
        end
    elseif __.blocks[name] then
        block = __.blocks[name]
    end
    if context then
        if block then
            block.body(__, context)
        else
            runtime_error(__, "block " .. name .. " not found")
        end
    else
        return block ~= nil
    end
end

--- Args of {% include(name, vars, ignore_missing, with_context) %}
func.args.include = {"name", "vars", "ignore_missing", "with_context"}

--- {% include(name, vars, ignore_missing, with_context) %}
--- @param compiler aspect.compiler
--- @param args table
function func.parsers.include(compiler, args)
    if compiler.tag_type == tag_type.EXPRESSION then
        args.with_vars = true
        return tags.include(compiler, args)
    else
        return '__.fn.include(__, ' .. args.name .. ', true, nil)'
    end
end

--- Include another template
--- @param __ aspect.output
--- @param names string|table
--- @param ignore boolean
--- @param context table|nil if nil it is just check
function func.fn.include(__, names, ignore, context)
    local view, error = __.opts.get(names)
    if not context then
        return view ~= nil
    end
    if error then
        runtime_error(__, error)
    elseif not view then
        if not ignore then
            runtime_error(__, "Template(s) not found. Trying " .. join(names, ", "))
        else
            return
        end
    end
    view.body(__, context)
end

--- {{ range() }}
func.args.range = {"from", "to", "step"}

--- @param __ aspect.output
--- @param args table
function func.fn.range(__, args)
    if not args.from then
        runtime_error(__, "range(): requires 'from' argument")
    end
    if not args.to then
        runtime_error(__, "range(): requires 'to' argument")
    end
    if not args.step or args.step == 0 then
        args.step = 1
    end
    if args.step > 0 and args.to < args.from then
        runtime_error(__, "range(): 'to' less than 'from' with positive step")
    elseif args.step < 0 and args.to > args.from then
        runtime_error(__, "range(): 'to' great than 'from' with negative step")
    end
    local t = {}
    for i = args.from, args.to, args.step do
        t[#t+1] = i
    end
    return t
end

--- @param __ aspect.output
--- @param from string
--- @param names table
function func.fn.import(__, from, names)
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
end

--- {{ date(date) }}
func.args.date = {"date"}

function func.fn.date(__, args)
    return date(args.date or false) or date(false)
end

func.args.dump = {"..."}

--- {% dump(...) %}
--- @param __ aspect.output
--- @param args table|nil
function func.fn.dump(__, args)
    local out = {__.view.name .. ":"..__.line .. ":"}
    if args then
        out[#out + 1] = dump(unpack(args))
    end
    out[#out + 1] = "\nStack:\n" .. __:get_callstack()
    return concat(out, "\n")
end

return func