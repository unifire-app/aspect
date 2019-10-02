local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local find = string.find
local insert = table.insert
local remove = table.remove
local concat = table.concat
local render = require("aspect.render")
local tokenizer = require("aspect.tokenizer")
local err = require("aspect.err")
local dump = require("pl.pretty").dump
local quote_string = require("pl.stringx").quote_string
local strcount = require("pl.stringx").count
local compiler_error = err.compiler_error
local sub = string.sub
local strlen = string.len
local pcall = pcall

--- @class aspect.compiler
--- @field includes
--- @field macros
--- @field extends
--- @field imports
--- @field render aspect.render
--- @field line number
--- @field tok aspect.tokenizer
local compiler = {
    OPS = {
        ["+"] = "+",
        ["-"] = "-",
        ["/"] = "/",
        ["*"] = "*",
        ["%"] = "%",
        ["**"] = "^",
    },
    COMPARISON_OP = {
        ["=="] = "==",
        ["!="] = "~=",
        [">="] = ">=",
        ["<="] = "<=",
        ["<"]  = "<",
        [">"]  = ">",
    },
    LOGIC_OP = {
        ["and"] = "and",
        ["or"] = "or"
    },
    RESERVED_VARS = {
        _self = true,
        _context = true,
        _charset = true,
        __ = true
    },
    RESERVED_WORDS = {
        ["and"] = true,
        ["break"] = true,
        ["do"] = true,
        ["else"] = true,
        ["elseif"] = true,
        ["end"] = true,
        ["false"] = true,
        ["for"] = true,
        ["function"] = true,
        ["if"] = true,
        ["in"] = true,
        ["local"] = true,
        ["nil"] = true,
        ["not"] = true,
        ["or"] = true,
        ["repeat"] = true,
        ["return"] = true,
        ["then"] = true,
        ["true"] = true,
        ["until"] = true,
        ["while"] = true,
    }
}


local mt = {__index = compiler}

--- @param aspect aspect.template
--- @param name string
--- @return aspect.compiler
function compiler.new(aspect, name)
    return setmetatable({
        aspect = aspect,
        name = name,
        line = 1,
        prev_line = 0,
        body = {},
        code = {},
        macros = {},
        blocks = {},
        var_names = {},
        deps = {},
        tags = {},
        idx  = 0
    }, mt)
end


function compiler:run(source)
    local ok, e = pcall(self.parse, self, source)
    if ok then
        return true
    else
        return false, err.new(e):set_name(self.name, self.line)
    end
end

function compiler:get_code()
    local code = {
        "local _self = {",
        "\tname = " .. quote_string(self.name) .. ",",
        "\tblocks = {},",
        "\tmacros = {},",
        "\tpairs = pairs,",
        "\tipairs = ipairs,",
        "\ttostring = tostring,",
        "\tconcat = table.concat,",
        "\tinsert = table.insert,",
        "\te = function (v) return v end,",
        "}",
        ""
    }

    if #self.body then
        insert(code, "function _self.body(__, ...)")
        insert(code, "\t_context = ...")
        for _, v in ipairs(self.body) do
            insert(code, "\t" .. v)
        end
        insert(code, "end\n")
    end

    if self.blocks then
        for n, b in pairs(self.blocks) do
            insert(code, "function _self.blocks." .. n .. "(__, ...)")
            insert(code, "\t_context = ...")
            for _, v in ipairs(b) do
                insert(code, "\t" .. v)
            end
            insert(code, "end\n")
        end
    end

    if self.macros then
        for n, m in pairs(self.macros) do
            insert(code, "function _self.macros." .. n .. "(__, _context)")
            for _, v in ipairs(m) do
                insert(code, "\t" .. v)
            end
            insert(code, "end\n")
        end
    end

    insert(code, "return _self")
    return concat(code, "\n")
end

function compiler:parse(source)
    local l = 1
    local s = find(source, "{", l, true)
    self.body = {}
    self.code = {self.body}
    self.macros = {}
    self.blocks = {}
    while s do
        if l < s - 1 then -- cut text before tag
            local frag = sub(source, l, s - 1)
            self:append_text(frag)
            self.line = self.line + strcount(frag, "\n")
        end
        local t, p = sub(source, s + 1, s + 1), s + 2
        if t == "{" then -- '{{'
            local tok = tokenizer.new(sub(source, s + 2))
            self:append_expr(self:parse_expresion(tok))
            if tok:is_valid() then
                compiler_error(tok, "syntax", "expecting end of tag")
            end
            local path = tok:get_path_as_string()
            l = s + strlen(path) + strlen(tok:get_token()) -- start tag pos + tag length + add final }}
            self.line = self.line + strcount(path, "\n")
            tok = nil
        elseif t == "%" then -- '{%'
            local tok = tokenizer.new(sub(source, s + 2))
            local parser = 'tag_' .. tok:get_token()
            if self[parser] then
                self:append_code(self[parser](self, tok:next())) -- call self:tag_{{ name }}
                if tok:is_valid() then
                    compiler_error(tok, "syntax", "expecting end of tag")
                end
            else
                compiler_error(nil, "syntax", "unknown tag '" .. tok:get_token() .. "'")
            end
            local path = tok:get_path_as_string()
            l = s + strlen(path) + strlen(tok:get_token()) -- start tag pos + tag length + add final %}
            self.line = self.line + strcount(path, "\n")
            tok = nil
        elseif t == "#" then
            s = find(source, "#}", p, true)
            l = s + 2
        end
        s = find(source, "{", s + 1, true)
    end
    self:append_text(sub(source, l))
end

--- Parse basic variable name like:
--- one
--- one.two
--- one["two"].three
--- @param tok aspect.tokenizer
function compiler:parse_variable(tok)
    if tok:is_word() then
        --if remember and not self.var_names[tok:get_token()] then
        --    self.var_names[tok:get_token()] = remember
        --end
        local var = {tok:get_token()}
        tok:next()
        while tok:is(".") or tok:is("[") do
            local mode = tok:get_token()
            tok:next()
            if tok:is_word() then
                insert(var, '["' .. tok:get_token() .. '"]')
                tok:next()
            elseif tok:is_string() then
                insert(var, '[' .. tok:get_token() .. ']')
                tok:next()
                if mode == "[" then
                    tok:require("]"):next()
                end
            else
                compiler_error(tok, "syntax", "expecting word or quoted string")
            end
        end
        return concat(var)
    else
        compiler_error(tok, "syntax", "expecting variable name")
    end
end

--- Parse array (list or hash)
--- [1,2,3]
--- {"one": 1, "two": 2}
--- @param tok aspect.tokenizer
function compiler:parse_array(tok)
    local vals = {}
    if tok:is("[") then
        tok:next()
        if tok:is("]") then
            return "{}"
        end
        while true do
            insert(vals, self:parse_expresion(tok))
            if tok:is(",") then
                tok:next()
            elseif tok:is(":") then
                compiler_error(tok, "syntax", "list can't have named keys, use hash instead")
            else
                break
            end
        end
        tok:require("]"):next()
    elseif tok:is("{") then
        tok:next()
        if tok:is("}") then
            return "{}"
        end
        while true do
            local key
            if tok:is_word() then
                key = '"' .. tok:get_token() .. '"'
                tok:next()
            elseif tok:is_string() or tok:is_number() then
                key = tok:get_token()
                tok:next()
            elseif tok:is("(") then
                key = self:parse_expresion(tok)
            end
            insert(vals, "[" .. key .. "] = " .. self:parse_expresion(tok:require(":"):next()))
            if tok:is(",") then
                tok:next()
            else
                break
            end
        end
        tok:require("}"):next()
    else
        compiler_error(tok, "syntax", "expecting list or hash")
    end
    return "{" .. concat(vals, ", ") .. "}"
end

--- @param tok aspect.tokenizer
--- @return string filter names
--- @return string arguments
--- @return number count of filter
function compiler:parse_filters(tok, var)
    while tok:is("|") do -- parse pipeline filter
        if tok:next():is_word() then
            local filter = tok:get_token()
            local args, no = nil, 1
            tok:next()
            if tok:is("(") then
                args = {}
                while not tok:is(")") and tok:is_valid() do -- parse arguments of the filter
                    tok:next()
                    local key
                    if tok:is_word() then
                        key = tok:get_token()
                        tok:next():require("="):next()
                        args[key] = self:parse_expresion(tok)
                    else
                        args[no] = self:parse_expresion(tok)
                    end
                    no = no + 1
                end
                tok:next()
            end
            if args then
                var = "_self.f['" .. filter .. "'](" .. var .. ", " .. concat(args, ", ") .. ")"
            else
                var = "_self.f['" .. filter .. "'](" .. var .. ")"
            end
        else
            compiler_error(tok, "syntax", "expecting filter name")
        end
    end
    return var
end

--- @param tok aspect.tokenizer
function compiler:parse_value(tok, remember)
    local var
    if tok:is_word() then -- is variable name
        var = self:parse_variable(tok, remember)
    elseif tok:is_string() or tok:is_number() then -- is string or number
        var = tok:get_token()
        tok:next()
    elseif tok:is("[") or tok:is("{") then -- is list or hash
        var = self:parse_array(tok)
    elseif tok:is("(") then -- is expression
        var = self:parse_expresion(tok)
    elseif tok:is("true") or tok:is("false") or tok:is("nil") then -- is regular true/false/nil
        var = tok:get_token()
        tok:next()
    elseif tok:is("null") then -- is null
        var = 'nil'
        tok:next()
    else
        compiler_error(tok, "syntax", "expecting any value")
    end
    if tok:is("|") then
        var = self:parse_filters(tok, var)
    end
    return var
end

--- Parse any expression (math, logic, string e.g.)
--- @param tok aspect.tokenizer
--- @param stats table|nil
function compiler:parse_expresion(tok, stats)
    stats = stats or {}
    stats.bools = stats.bools or 0
    local elems = {}
    local comp_op = false -- only one comparison may be in the expression
    local logic_op = false
    while true do
        local element
        local not_op = ""

        -- 1. checks unary operator 'not'
        if tok:is("not") then
            not_op = "not "
            tok:next()
        end
        -- 2. parse value
        if tok:is("(") then
            element = "(" .. self:parse_expresion(tok:next()) .. ")"
            tok:require(")"):next()
        else
            element = self:parse_value(tok)
        end
        -- 3. check operator 'in' or 'not in' and 'is' or 'is not'
        if tok:is("in") or tok:is("not") then
            if tok:is("not") then
                insert(elems, "not")
            end
            tok:require("in"):next()
            element = "_self.f['in'](" .. element .. ", " ..  self:parse_expresion(tok) .. ")"
        elseif tok:is("is") then
            element = self:parse_test(tok, element)
        end
        if logic_op then
            stats.bools  = stats.bools + 1
            insert(elems, not_op .. "__.b(" .. element .. ")")
        else
            insert(elems, not_op ..element)
        end
        local op = false
        comp_op = false

        -- 4. checks and parse math/logic/comparison/concat operator
        if self.OPS[tok:get_token()] then -- math
            insert(elems, self.OPS[tok:get_token()])
            tok:next()
            op = true
            logic_op = false
        elseif self.COMPARISON_OP[tok:get_token()] then -- comparison
            if comp_op then
                compiler_error(tok, "syntax", "only one comparison operator may be in the expression")
            end
            insert(elems, self.COMPARISON_OP[tok:get_token()])
            tok:next()
            op = true
            comp_op = true
            logic_op = false
        elseif self.LOGIC_OP[tok:get_token()] then -- logic
            if not logic_op then
                stats.bools  = stats.bools + 1
                elems[#elems] = "__.b(" .. elems[#elems] .. ")"
            end
            insert(elems, self.LOGIC_OP[tok:get_token()])
            tok:next()
            op = true
            comp_op = false
            logic_op = true
        elseif tok:is("~") then -- concat
            insert(elems, "..")
            tok:next()
            op = true
            logic_op = false
        else
            logic_op = false
        end
        -- 5. if no more math/logic/comparison/concat operators found - work done
        if not op then
            break
        end
    end
    if comp_op then -- comparison with nothing?
        compiler_error(tok, "syntax", "expecting expression statement")
    end
    stats.count = (#elems + 1)/2
    stats.all_bools = logic_op == stats.count -- all elements converted to boolean?
    return concat(elems, " ")
end

--- Append any text
--- @param text string
function compiler:append_text(text)
    local tag = self:get_last_tag()
    local line = self:get_checkpoint()
    local code = self.code[#self.code]
    if line then
        insert(code, line)
    end
    if tag and tag.append_text then
        insert(code, tag.append_text(tag, text))
    else
        insert(code, "__(" .. quote_string(text) .. ")")
    end
end

function compiler:append_expr(lua)
    local tag = self:get_last_tag()
    local line = self:get_checkpoint()
    local code = self.code[#self.code]
    if line then
        insert(code, line)
    end
    if tag and tag.append_expr then
        insert(code, tag.append_expr(tag, lua))
    else
        insert(code, "__(_self.e(" .. lua .. "))")
    end
end

function compiler:append_code(lua)
    local tag = self:get_last_tag()
    local line= self:get_checkpoint()
    local code = self.code[#self.code]
    if line then
        insert(code, line)
    end
    if type(lua) == "table" then
        for _, l in ipairs(lua) do
            if tag and tag.append_code then
                insert(code, tag.append_code(tag, l))
            else
                insert(code, l)
            end
        end
    else
        if tag and tag.append_code then
            insert(code, tag.append_code(tag, lua))
        else
            insert(code, lua)
        end
    end
end

function compiler:get_checkpoint()
    if self.prev_line ~= self.line then
        self.prev_line = self.line
        return "__.line = " .. self.line
    else
        return nil
    end
end


--- @param tok aspect.tokenizer
function compiler:tag_for(tok)
    local key, value, from, cond

    if tok:is_word() then
        value = tok:get_token()
        if self.RESERVED_WORDS[value] then
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

    from = self:parse_expresion(tok:require("in"):next())
    local tag = self:push_tag('for')

    if tok:is('if') then
        tok:next()
        local info = {}
        cond =  self:parse_expresion(tok, info)
        if info.bools == info.count then
            return "if __.b(" .. cond .. ") then"
        end
        tag.cond = true
    end
    local lua = {}
    if key then
        insert(lua, 'for ' .. key .. ', ' .. value .. ' in _self.pairs(' .. from .. ') do')
    else
        insert(lua, 'for _, ' .. value .. ' in _self.ipairs(' .. from .. ') do')
    end
    if cond then
        insert(lua, 'if __.b(' .. cond .. ') then')
    end

    return concat(lua, " ")
end

function compiler:tag_endfor()
    local tag = self:pop_tag('for')
    if tag.cond then
        return "end end"
    else
        return "end"
    end
end

--- IF
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_if(tok)
    self:push_tag('if')
    local stats = {}
    local exp =  self:parse_expresion(tok, stats)
    if stats.bools == stats.count then
        return "if " .. exp .. " then"
    else
        return "if __.b(" .. exp .. ") then"
    end
end

--- ELSEIF
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_elseif(tok)
    return "elseif " .. self:parse_expresion(tok) .. " then"
end

--- ELIF aka ELSEIF
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_elif(tok)
    return self:tag_elseif(tok)
end

--- ELSE
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_else(tok)
    return 'else'
end

--- ENDIF
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_endif(tok)
    self:pop_tag('if')
    return 'end'
end

--- {% set %}
--- @param tok aspect.tokenizer
--- @return string
function compiler:tag_set(tok)
    local var = self:parse_variable(tok)
    if tok:is("|") or not tok:is_valid() then
        local tag = self:push_tag("set")
        local id = tag.id
        tag.var = var
        if tok:is("|") then
            tag.final = self:parse_filters(tok, '_self.concat(_' .. tag.id .. ')')
        else
            tag.final = '_self.concat(_' .. tag.id .. ')'
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
        return var .. ' = ' .. self:parse_expresion(tok:next())
    end
end

function compiler:tag_endset(tok)
    tok:next()
    local tag = self:pop_tag("set")
    return {
        tag.var .. " = " .. tag.final,
        "end"
    }
end

--- @param tok aspect.tokenizer
function compiler:tag_block(tok)
    if not tok:is_word() and not tok:is_keyword() then
        compiler_error(tok, "syntax", "expecting a valid block name")
    end
    local name = tok:get_token()
    tok:next()
    self.blocks[name] = {}
    self:push_tag("block", self.blocks[name])
end

function compiler:tag_endblock()
    self:pop_tag("block")
end

--- @param tok aspect.tokenizer
function compiler:tag_macro(tok)
    if not tok:is_word() and not tok:is_keyword() then
        compiler_error(tok, "syntax", "expecting a valid macro name")
    end
    local name = tok:get_token()
    self.macros[name] = {}
    self:push_tag("macro", self.macros[name])
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
                self:append_code(arg .. self:parse_expresion(tok))
            else
                self:append_code(arg .. " nil")
            end
            no = no + 1
        until not tok:is(",")
        tok:require(")"):next()
    end
end

function compiler:tag_endmacro()
    self:pop_tag("macro")
end

--- Push the tag in tag's stacks
--- @param name string the tag name
--- @param code_space table|nil for lua code
function compiler:push_tag(name, code_space)
    local code_space_id
    self.idx = self.idx + 1
    if code_space then
        insert(self.code, code_space)
        code_space_id = #self.code
    end
    local tag = {
        id = self.idx,
        name = name,
        line = self.line,
        code_space_no = code_space_id
    }
    local prev = self.tags[#self.tags]
    if prev then
        if prev.append_text then
            tag.append_text = prev.append_text
        end
        if prev.append_expr then
            tag.append_expr = prev.append_expr
        end
        if prev.append_code then
            tag.append_code = prev.append_code
        end
    end
    insert(self.tags, tag)
    return tag
end

--- Remove tag from stack
--- @param name string the tag name
function compiler:pop_tag(name)
    if #self.tags then
        local tag = self.tags[#self.tags]
        if tag.name == name then
            if tag.code_space_no then
                if tag.code_space_no ~= #self.code then -- dummy protection
                    compiler_error(nil, "compiler", "invalid code space layer in the tag")
                else
                    remove(self.code)
                end
            end
            return remove(self.tags)
        else
            compiler_error(nil, "syntax",
               "unexpected tag 'end" .. name .. "'. Expecting tag 'end" .. tag.name .. "' (opened on line " .. tag.line .. ")")
        end
    else
        compiler_error(nil, "syntax", "unexpected tag 'end" .. name .. "'. Tag ".. name .. " never opened")
    end
end

function compiler:get_last_tag()
    if #self.tags then
        return self.tags[#self.tags]
    else
        return nil
    end
end

return compiler