local err = require("aspect.err")
local compiler_error = err.compiler_error
local quote_string = require("pl.stringx").quote_string
local config = require("aspect.config")
local utils = require("aspect.utils")
local reserved_words = config.compiler.reserved_words
local loop_keys = config.loop.keys
local tag_type = config.compiler.tag_type
local import_type = config.macro.import_type
local concat = table.concat
local insert = table.insert
local tostring = tostring
local pairs = pairs

local tags = {}

--- {% set %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_set(compiler, tok)
    local opts = {}
    local var = compiler:parse_var_name(tok, opts)
    if opts.var_system then
        compiler_error(tok, "syntax", "the system variable can not be changed")
    end
    if tok:is("|") or not tok:is_valid() then
        local tag = compiler:push_tag("set")
        local id = tag.id
        tag.var = var
        if tok:is("|") then
            tag.final = compiler:parse_filters(tok, '__.concat(_' .. tag.id .. ')')
        else
            tag.final = '__.concat(_' .. tag.id .. ')'
        end
        tag.append_text = function (_, text)
            return '_' .. id .. '[#_'.. id .. ' + 1] = ' .. quote_string(text)
        end
        tag.append_expr = function (_, lua)
            return '_' .. id .. '[#_'.. id .. ' + 1] = ' .. lua
        end
        return {
            "local " .. tag.var,
            "do",
            "local _" .. tag.id .. " = {}"
        }
    elseif tok:is("=") then
        compiler:push_var(var)
        compiler.tag_type = tag_type.EXPRESSION -- switch tag mode
        return 'local ' .. var .. ' = ' .. compiler:parse_expression(tok:next())
    end
end

--- {% do %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_do(compiler, tok)
    return compiler:parse_expression(tok)
end

--- {% endset %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_endset(compiler, tok)
    tok:next()
    local tag = compiler:pop_tag("set")
    compiler:push_var(tag.var)
    return {
        tag.var .. " = " .. tag.final,
        "end"
    }
end

--- {% extends %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_extends(compiler, tok)
    if compiler.extends then
        compiler_error(tok, 'syntax', "Template already extended")
    end
    local info = {}
    local name = compiler:parse_expression(tok, info)
    if info.type == "string" then
        compiler.extends = {value = name, static = true}
        compiler.uses_tpl[name] = true
    else
        compiler.extends = {value = name, static = false}
    end
end

--- {% block block_name %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_block(compiler, tok)
    if not tok:is_word() then
        compiler_error(tok, "syntax", "expecting a valid block name")
    end
    if compiler:get_last_tag('macro') then
        compiler_error(tok, "syntax", "blocks can\'t be defined or used in macro")
    end
    local name = tok:get_token()
    tok:next()
    compiler.blocks[name] = {
        code = {},
        parent = false,
        vars = {},
        desc = nil,
        start_line = compiler.line
    }
    local tag_for, pos = compiler:get_last_tag("for") -- may be {{ loop }} used in the block (which may be replaced)
    while tag_for do
        tag_for.has_loop = true
        tag_for, pos = compiler:get_last_tag("for", pos - 1)
    end
    local tag = compiler:push_tag("block", compiler.blocks[name].code, "block." .. name, {})
    tag.block_name = name
end

--- {% endblock %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_endblock(compiler, tok)
    local tag = compiler:pop_tag("block")
    if tok:is_valid() then
        if tok:is(tag.block_name) then
            tok:next()
        else
            compiler_error(tok, "syntax", "expecting block name " .. tag.block_name)
        end
    end
    compiler.blocks[tag.block_name].parent = tag.parent
    compiler.blocks[tag.block_name].end_line = compiler.line
    local vars = utils.implode_hashes(compiler:get_local_vars())
    if vars then
        return '__.blocks.' .. tag.block_name .. '.body(__, __.setmetatable({ ' .. vars .. '}, { __index = _context }))' ;
    else
        return '__.blocks.' .. tag.block_name .. '.body(__, _context)' ;
    end
end

--- {% use %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_use(compiler, tok)
    if tok:is_string() then
        local uses = {
            name = tok:get_token(),
            line = compiler.line
        }
        compiler.uses_tpl[uses.name] = true
        compiler.uses[#compiler.uses + 1] = uses
        tok:next()
        if tok:is('with') then
            uses.with = {}
            tok:next()
            while tok:is_valid() do
                local block_name = tok:get_token()
                local alias_name = tok:next():require("as"):next():get_token()
                uses.with[block_name] = quote_string(alias_name)
                if not tok:next():is(",") then
                    break
                end
            end
        end
    else
        compiler_error(tok, "syntax", "the template name")
    end
end

--- {% macro %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_macro(compiler, tok)
    if not tok:is_word() then
        compiler_error(tok, "syntax", "expecting a valid macro name")
    end
    local name = tok:get_token()
    compiler.macros[name] = {}
    local tag = compiler:push_tag("macro", compiler.macros[name], "macro." .. name, {})
    tag.macro_name = name
    if tok:next():is("(") then
        local no = 1
        repeat
            tok:next()
            if tok:is(")") then
                break
            end
            if not tok:is_word() then
                compiler_error(tok, "syntax", "expecting argument name")
            end
            local key = tok:get_token()
            local arg  = "local " .. key .. " = _context." .. key .. " or _context[" .. no .. "] or "
            compiler:push_var(key)
            tok:next()
            if tok:is("=") then
                tok:next()
                compiler:append_code(arg .. compiler:parse_expression(tok))
            else
                compiler:append_code(arg .. " nil")
            end
            no = no + 1
        until not tok:is(",")
        tok:require(")"):next()
    end
end

--- {% endmacro %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_endmacro(compiler, tok)
    local tag = compiler:pop_tag("macro")
    if tok:is_valid() then
        tok:require(tag.macro_name):next()
    end
end

--- {% include {'tpl_1', 'tpl_2'} ignore missing only with {foo = 1} with context with vars %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_include(compiler, tok, ...)
    local info = {}
    local args = {
        name = compiler:parse_expression(tok, info),
        with_vars = true,
        with_context = true
    }
    if info.type == "string" then
        compiler.uses_tpl[args.name] = true
    end
    if tok:is('ignore') then
        tok:next():require('missing'):next()
        args.ignore_missing = true
    end
    if tok:is("only") then
        args.with_context = false
        args.with_vars = false
        tok:next()
    end
    while tok:is_valid() and tok:is('with') or tok:is('without') do
        local w = false
        if tok:is('with') then
            w = true
        end
        tok:next()
        if tok:is('context') then
            tok:next()
            args.with_context = w
        elseif tok:is('vars') then
            tok:next()
            args.with_vars = w
        elseif tok:is('{') then
            if not w then
                compiler_error(tok, "syntax", "'without' operator cannot be to apply to variables")
            end
            args.vars = compiler:parse_hash(tok)
        else
            compiler_error(tok, "syntax", "expecting 'context', 'vars' or variables")
        end
    end

    return tags.include(compiler, args)
end

---
--- @param compiler aspect.compiler
--- @param args table
---   args.name - tpl_1 or {'tpl_1', 'tpl_2'}
---   args.ignore - ignore missing
---   args.vars — {foo = 1, bar = 2}
---   args.with_context - with context
---   args.with_vars - with vars
function tags.include(compiler, args)
    local vars, context = args.vars
    if args.with_vars then
        vars = utils.implode_hashes(vars, compiler:get_local_vars())
        local tag, pos = compiler:get_last_tag("for") -- may be {{ loop }} used in included template
        while tag do
            tag.has_loop = true
            tag, pos = compiler:get_last_tag("for", pos - 1)
        end
    else
        vars = utils.implode_hashes(vars)
    end

    if vars and args.with_context then
        context = "__.setmetatable({" .. vars .. "}, { __index = _context })"
    elseif vars and not args.with_context then
        context = "{" .. vars .. "}"
    elseif not vars and args.with_context then
        context = "_context"
    else -- not with and not with_context
        context = "{}"
    end

    return '__.fn.include(__, ' .. args.name .. ', ' .. tostring(args.ignore_missing) .. ', ' .. context .. ')'
end

--- {% import %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_import(compiler, tok)
    local info = {}
    local from = compiler:parse_expression(tok, info)
    if info.type == "string" then
        compiler.uses_tpl[from] = true
    end
    tok:require("as"):next()
    local name = compiler:parse_var_name(tok)
    compiler.import[name] = import_type.GROUP
    return 'local ' .. name .. ' = __.fn.import(__, ' .. from .. ')'
end

--- {% from %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_from(compiler, tok)
    local info = {}
    local from = compiler:parse_expression(tok, info)
    if info.type == "string" then
        compiler.uses_tpl[from] = true
    end
    tok:require("import"):next()
    local names, aliases = {}, {}
    while tok:is_valid() do
        info = {}
        local name = compiler:parse_var_name(tok, info)
        if info.var_system then
            compiler_error(tok, "syntax", "system variables can't be changed")
        end
        insert(names, quote_string(name))
        if tok:is("as") then
            name = compiler:parse_var_name(tok:next(), info)
            compiler.import[name] = import_type.SINGLE
            insert(aliases, name)
            if info.var_system then
                compiler_error(tok, "syntax", "system variables can't be changed")
            end
        else
            compiler.import[name] = import_type.SINGLE
            insert(aliases, name)
        end
        if tok:is(",") then
            tok:next()
        else
            break
        end
    end
    return 'local ' .. concat(aliases, ", ") .. ' = __.fn.import(__, ' .. from .. ', {'.. concat(names, ", ") .. '})'
end

--- {% for %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_for(compiler, tok)
    local key, value, from, cond
    if tok:is_word() then
        value = tok:get_token()
        if reserved_words[value] then
            compiler_error(tok, "syntax", "reserved words can not be used as variable name")
        end
        compiler:push_var(value)
        tok:next()
    else
        compiler_error(tok, "syntax", "expecting variable name")
    end

    if tok:is(",") then
        key = value
        if tok:next():is_word() then
            value = tok:get_token()
            if reserved_words[value] then
                compiler_error(tok, "syntax", "reserved words can not be used as variable name")
            end
            compiler:push_var(value)
            tok:next()
        else
            compiler_error(tok, "syntax", "expecting variable name")
        end
    end
    local tag = compiler:push_tag('for', {})
    from = compiler:parse_expression(tok:require("in"):next())
    tag.has_loop = false
    tag.from = from
    tag.value = value
    tag.key = key
    while tok:is_valid() do
        if tok:is('if') then
            tok:next()
            local info = {}
            cond = compiler:parse_expression(tok, info)
            if info.type == "boolean" then
                tag.cond = "if " .. cond .. " then"
            else
                tag.cond = "if __.b(" .. cond .. ") then"
            end
        elseif tok:is("recursive") then
            if tag.nestedset then
                compiler_error(tok, "syntax", "nestedset() already declared")
            end
            tok:require("("):next()
            tag.recursive = compiler:parse_expression(tok:next())
            tok:require(")"):next()
        elseif tok:is("nestedset") then
            if tag.recursive then
                compiler_error(tok, "syntax", "recursive() already declared")
            end
            tok:require("(")
            tag.nestedset = {
                left = compiler:parse_expression(tok:next()),
                right = compiler:parse_expression(tok:require(","):next()),
                level = compiler:parse_expression(tok:require(","):next())
            }
            tok:require(")"):next()
        else
            break
        end
    end
end

--- {% break  %}
function tags.tag_break(compiler, tok)
    local tag = compiler:get_last_tag()
    if not tag then
        compiler_error(tok, "syntax")
    end
    if tag.name ~= "for" then
        compiler_error(tok, "syntax", "'break' allows only in 'for' tag")
    end
    return 'break'
end

--- {% endfor %}
--- @param compiler aspect.compiler
function tags.tag_endfor(compiler)
    local tag = compiler:pop_tag('for')
    local lua = tag.code_space
    local before = {}
    if tag.has_loop then
        if tag.has_loop == true then -- use all keys of {{ loop }}
            tag.has_loop = loop_keys
        end
        if tag.has_loop.revindex or tag.has_loop.revindex0 or tag.has_loop.last then
            tag.has_loop.length = true
        end
        --- before for
        before[#before + 1] = "do"
        before[#before + 1] = "local loop = {"
        if tag.has_loop.iteration then
            before[#before + 1] = "\titeration = 1,"
        end
        if tag.has_loop.first then
            before[#before + 1] = "\tfirst = true,"
        end
        if tag.has_loop.length or tag.has_loop.revindex or tag.has_loop.revindex0 or tag.has_loop.last then
            before[#before + 1] = "\tlength = __.f.length(" .. tag.from .. "),"
        end
        if tag.has_loop.index or tag.has_loop.last then
            before[#before + 1] = "\tindex = 1,"
        end
        if tag.has_loop.index0 then
            before[#before + 1] = "\tindex0 = 0,"
        end
        before[#before + 1] = "}"
        if tag.has_loop.revindex then
            before[#before + 1] = "loop.revindex = loop.length - 1"
        end
        if tag.has_loop.revindex0 then
            before[#before + 1] = "loop.revindex0 = loop.length"
        end
        if tag.has_loop.last then
            before[#before + 1] = "loop.last = (length == 1)"
        end
    end

    if tag.key then -- start of 'for'
        before[#before + 1] = 'for ' .. tag.key .. ', ' .. tag.value .. ' in __.iter(' .. tag.from .. ') do'
    else
        before[#before + 1] = 'for _, ' .. tag.value .. ' in __.iter(' .. tag.from .. ') do'
    end
    if tag.cond then -- start of 'if'
        before[#before + 1] = tag.cond
    end

    if tag.has_loop then
        if tag.has_loop.iteration then
            lua[#lua + 1] = "loop.iteration = loop.iteration + 1"
        end
        if tag.has_loop.prev_item then
            lua[#lua + 1] = "loop.prev_item = " .. tag.value
        end
    end
    if tag.cond then -- end of 'if'
        lua[#lua + 1] = "end"
    end
    if tag.has_loop then -- after for body
        if tag.has_loop.first then
            lua[#lua + 1] = "if loop.first then loop.first = false end"
        end
        if tag.cond then -- end of 'if'
            lua[#lua + 1] = "end"
        end
        if tag.has_loop.index or tag.has_loop.last then
            lua[#lua + 1] = "loop.index = loop.index + 1"
        end
        if tag.has_loop.index0 then
            lua[#lua + 1] = "loop.index0 = loop.index0 + 1"
        end
        if tag.has_loop.revindex then
            lua[#lua + 1] = "loop.revindex = loop.revindex - 1"
        end
        if tag.has_loop.revindex0 then
            lua[#lua + 1] = "loop.revindex0 = loop.revindex0 - 1"
        end
        if tag.has_loop.last then
            lua[#lua + 1] = "if loop.length == loop.index then loop.last = true end"
        end
        lua[#lua + 1] = "end" -- end of 'do'
    end
    lua[#lua + 1] = "end" -- end if 'for'
    utils.prepend_table(before, lua)
    return lua
end

--- {% if %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_if(compiler, tok)
    compiler:push_tag('if')
    local stats = {}
    local exp =  compiler:parse_expression(tok, stats)
    if stats.type == "boolean" then
        return "if " .. exp .. " then"
    else
        return "if __.b(" .. exp .. ") then"
    end
end

--- {% elseif %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_elseif(compiler, tok)
    return "elseif __.b(" .. compiler:parse_expression(tok) .. ") then"
end

--- {% elif %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_elif(compiler, tok)
    return compiler:tag_elseif(tok)
end

--- {% else %}
--- @param compiler aspect.compiler
--- @return string
function tags.tag_else(compiler)
    local tag = compiler:get_last_tag()
    if not tag then
        compiler_error(nil, "syntax", "Unexpected tag 'else', no one tag opened")
    end
    if tag.name ~= "for" and tag.name ~= "if" then
        compiler_error(nil, "syntax", "Unexpected tag 'else'")
    end
    return 'else'
end

--- {% endif %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_endif(compiler, tok)
    compiler:pop_tag('if')
    return 'end'
end

--- {% autoescape %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_autoescape(compiler, tok)
    local state = "true"
    if tok:is_boolean() then
        state = tok:get_token()
        tok:next()
    end
    local tag = compiler:push_tag('autoescape')
    return '__' .. tag.id .. " = __:autoescape(" .. state .. ")"
end

--- {% endautoescape %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_endautoescape(compiler)
    local tag = compiler:pop_tag('autoescape')
    return "__:autoescape(__" .. tag.id .. ")"
end

--- {% verbatim %}
--- @param compiler aspect.compiler
function tags.tag_verbatim(compiler)
    compiler.ignore = "endverbatim"
    compiler:push_tag("verbatim")
end

--- {% endverbatim %}
--- @param compiler aspect.compiler
function tags.tag_endverbatim(compiler)
    compiler:pop_tag("verbatim")
    return "local z=1"
end

--- {% with %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_with(compiler, tok)
    local code = {"do"}
    local dynamic = false -- all variables for scope from variable e.g. {% with vars %}
    local vars
    if tok:is("{") then
        vars = compiler:parse_hash(tok)

    elseif tok:is_word() then
        dynamic = tok:get_token()
        tok:next()
    end
    if tok:is("only") then
        compiler:push_tag("with", nil, nil, {})
        tok:next()
        if dynamic then
            code[#code + 1] = "local _context = __.t(" .. dynamic .. ")"
        elseif vars then
            code[#code + 1] = "local _context = {" .. utils.implode_hashes(vars) .. "}"
        else
            code[#code + 1] = "local _context = {}"
        end
    else
        compiler:push_tag("with")
        if vars then
            for k, v in pairs(vars) do
                code[#code + 1] = "local " .. k .. " = " .. v
                compiler:push_var(k)
            end
        end
        if dynamic then
            code[#code + 1] = "local _context = __.setmetatable(__.t(" .. dynamic .. "), { __index = _context })"
        else
            -- allows __context
        end
    end

    return code
end

--- {% endwith %}
--- @param compiler aspect.compiler
--- @return string
function tags.tag_endwith(compiler)
    compiler:pop_tag("with")
    return "end"
end

return tags