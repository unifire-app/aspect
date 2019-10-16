local err = require("aspect.err")
local compiler_error = err.compiler_error
local quote_string = require("pl.stringx").quote_string

local func = {}

--- {% parent() %}
--- @param compiler aspect.compiler
function func.parse_parent(compiler)
    local tag = compiler:get_last_tag("block")
    if not tag then
        compiler_error(nil, "syntax", "{% parent %} should be called in the block")
    end
    local vars = compiler.utils.implode_hashes(compiler:get_local_vars())
    if vars then
        return '__:parent(' .. quote_string(tag.block_name) .. ', __.setmetatable({ ' .. vars .. '}, { __index = _context }))' ;
    else
        return '__:parent(' .. quote_string(tag.block_name) .. ', _context)' ;
    end
end

--- {% block(name[, template]) %}
--- @param compiler aspect.compiler
--- @param args table
function func.parse_block(compiler, args)
    if not args.name then
        compiler_error(nil, "syntax", "function block() requires argument 'name'")
    end
end

return func