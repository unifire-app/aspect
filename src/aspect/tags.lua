local err = require("aspect.err")
local compiler_error = err.compiler_error
local quote_string = require("pl.stringx").quote_string
local reserved_words = require("aspect.config").compiler.reserved_words
local concat = table.concat

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
        tag.append_text = function (tg, text)
            return '_' .. id .. '[#_'.. id .. ' + 1] = ' .. quote_string(text)
        end
        tag.append_expr = function (tg, lua)
            return '_' .. id .. '[#_'.. id .. ' + 1] = ' .. lua
        end
        return {
            "local " .. tag.var,
            "do",
            "local _" .. tag.id .. " = {}"
        }
    elseif tok:is("=") then
        compiler:push_var(var)
        return 'local ' .. var .. ' = ' .. compiler:parse_expression(tok:next())
    end
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
    if tok:is_string() then
        local pos, expr = tok.count, compiler:parse_expression(tok)
        if tok.count - pos == 1 then -- if only 1 token and it is string
            compiler.extends = {value = expr, static = true}
        else
            compiler.extends = {value = expr, static = false}
        end
    else
        compiler.extends = {value = compiler:parse_expression(tok), static = false}
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
    compiler.blocks[name] = {}
    local tag = compiler:push_tag("block", compiler.blocks[name], "block." .. name)
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
    local vars = compiler.utils.implode_hashes(compiler:get_local_vars())
    if vars then
        return '__.blocks.' .. tag.block_name .. '(__, __.setmetatable({ ' .. vars .. '}, { __index = _context }))' ;
    else
        return '__.blocks.' .. tag.block_name .. '(__, _context)' ;
    end
end

--- {% parent %}
--- @param compiler aspect.compiler
function tags.tag_parent(compiler)
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

--- {% use %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_use(compiler, tok)

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
    compiler:push_tag("macro", compiler.macros[name], "macro." .. name)
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
    compiler:pop_tag("macro")
end

--- {% include {'tpl_1', 'tpl_2'} ignore missing only with {foo = 1} with context with vars %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_include(compiler, tok)
    local with_vars, with_context, with =  true, true, nil
    local inc = {
        [1] = compiler:parse_expression(tok),
        [2] = "false",
        [3] = "_context"
    }
    if tok:is('ignore') then
        tok:next():require('missing'):next()
        inc[2] = 'true'
    end
    if tok:is("only") then
        with_context = false
        with_vars = false
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
            with_context = w
        elseif tok:is('vars') then
            tok:next()
            with_vars = w
        elseif tok:is('{') then
            if not w then
                compiler_error(tok, "syntax", "'without' operator cannot be applied to variables")
            end
            with = compiler:parse_hash(tok)
        else
            compiler_error(tok, "syntax", "expecting 'context', 'vars' or variables")
        end
    end

    if with_vars then
        with = compiler.utils.implode_hashes(with, compiler:get_local_vars())
    else
        with = compiler.utils.implode_hashes(with)
    end

    if with and with_context then
        inc[3] = "__.setmetatable({" ..with .. "}, { __index = _context })"
    elseif with and not with_context then
        inc[3] = "{" ..with .. "}"
    elseif not with and with_context then
        inc[3] = "_context"
    else -- not with and not with_context
        inc[3] = "{}"
    end

    return '__:include(' .. inc[1] .. ', ' .. inc[2] .. ', ' .. inc[3] .. ')'
end

--- {% import %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_import(compiler, tok)
    local from = compiler:parse_expression(tok)
    tok:require("as"):next()
    local name = compiler:parse_var_name(tok)
    return 'local ' .. name .. ' = __.import(' .. from .. ')'
end

--- {% from %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function tags.tag_from(compiler, tok)
    local from = compiler:parse_expression(tok)
    tok:require("import"):next()
    local name = compiler:parse_var_name(tok)
    return 'local ' .. name .. ' = __.import(' .. from .. ')'
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
        tok:next()
    else
        compiler_error(tok, "syntax", "expecting variable name")
    end

    if tok:is(",") then
        key = value
        if tok:next():is_word() then
            value = tok:get_token()
            tok:next()
        else
            compiler_error(tok, "syntax", "expecting variable name")
        end
    end

    from = compiler:parse_expression(tok:require("in"):next())
    local tag = compiler:push_tag('for')

    if tok:is('if') then
        tok:next()
        local info = {}
        cond =  compiler:parse_expression(tok, info)
        if info.bools == info.count then
            return "if __.b(" .. cond .. ") then"
        end
        tag.cond = true
    end
    local lua = {}
    if key then
        lua[#lua + 1] = 'for ' .. key .. ', ' .. value .. ' in __.pairs(' .. from .. ') do'
    else
        lua[#lua + 1] = 'for _, ' .. value .. ' in __.ipairs(' .. from .. ') do'
    end
    if cond then
        lua[#lua + 1] ='if __.b(' .. cond .. ') then'
    end

    return concat(lua, " ")
end

--- {% endfor %}
--- @param compiler aspect.compiler
function tags.tag_endfor(compiler)
    local tag = compiler:pop_tag('for')
    if tag.cond then
        return "end end"
    else
        return "end"
    end
end

--- {% if %}
--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
--- @return string
function tags.tag_if(compiler, tok)
    compiler:push_tag('if')
    local stats = {}
    local exp =  compiler:parse_expression(tok, stats)
    if stats.bools == stats.count then
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



return tags