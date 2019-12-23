local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs
local type = type
local ipairs = ipairs
local find = string.find
local insert = table.insert
local remove = table.remove
local concat = table.concat
local tokenizer = require("aspect.tokenizer")
local tags = require("aspect.tags")
local tests = require("aspect.tests")
local err = require("aspect.err")
local write = require("pl.pretty").write
local quote_string = require("pl.stringx").quote_string
local strcount = require("pl.stringx").count
local tablex = require("pl.tablex")
local compiler_error = err.compiler_error
local sub = string.sub
local strlen = string.len
local pcall = pcall
local config = require("aspect.config")
local import_type = config.macro.import_type
local loop_keys = config.loop.keys
local tag_type = config.compiler.tag_type
local strip_pattern = config.compiler.strip
local func = require("aspect.funcs")
local filters = require("aspect.filters")
local ast = require("aspect.ast")
local utils = require("aspect.utils")
local rstrip = utils.rtrim
local lstrip = utils.ltrim
local special = config.compiler.special

--- @class aspect.tag
--- @field id number unique ID of the tag in compilation
--- @field name string tag name
--- @field line number where the tag opened
--- @field code_space table own table for code
--- @field code_space_no number stack number of own table of code
--- @field code_start_line number
--- @field var_space table own table of variables
--- @field var_space_no number stack number of own table of variables
--- @field append_text fun(tpl:aspect.compiler, text:string)
--- @field append_expr fun(tpl:aspect.compiler, expr:string)
--- @field append_code fun(tpl:aspect.compiler, code:string)
local _ = {}

--- @class aspect.compiler.blocks
--- @field code table<string> list of lua code of the block
--- @field parent boolean has parent function inside
--- @field vars table list of used variables
--- @field desc string the description
--- @field start_line number of line there block started
--- @field end_line number of line there block ended
local _ = {}

--- @class aspect.compiler
--- @field aspect aspect.template
--- @field name string
--- @field blocks table<aspect.compiler.blocks>
--- @field macros table<table> table of macros with their code (witch array)
--- @field extends string|boolean if true then we has dynamic extend
--- @field import table
--- @field uses table
--- @field line number
--- @field tag_name string the current tag
--- @field ignore string|nil
--- @field tok aspect.tokenizer
--- @field tags table<aspect.tag>
--- @field code table stack of code. Each level is isolated code (block or macro). 0 level is body
--- @field stats boolean
local compiler = {
    version = 1,
}

local mt = { __index = compiler }

--- @param aspect aspect.template
--- @param name string
--- @return aspect.compiler
function compiler.new(aspect, name, stats)
    return setmetatable({
        aspect = aspect,
        name = name,
        line = 1,
        prev_line = 1,
        body = {},
        code = {},
        macros = {},
        extends = nil,
        blocks = {},
        uses = {},
        uses_tpl = {},
        used_vars = {},
        vars = {},
        deps = {},
        tags = {},
        idx  = 0,
        use_vars = {},
        tag_type = nil,
        import = {},
        ignore = nil,
        stats = stats or true,
    }, mt)
end

--- Start compiler
--- @param source string source code of the template
--- @return boolean ok or not ok
--- @return aspect.error if not ok returns error
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
        "\tv = " .. self.version .. ",",
        "\tname = " .. quote_string(self.name) .. ",",
        "\tblocks = {},",
        "\tmacros = {},",
        --"\tvars = {},",
    }
    --insert(code, "\tvars = " .. write(self.used_vars))
    if self.extends then
        if self.extends.static then
            insert(code,"\textends = " .. self.extends.value .. ",")
        else
            insert(code,"\textends = true")
        end
    end
    if self.uses and #self.uses > 0 then
        insert(code,"\tuses = {")
        for _, use in ipairs(self.uses) do
            insert(code,"\t\t{")
            insert(code,"\t\t\tname = " .. use.name .. ", ")
            insert(code,"\t\t\tline = " .. use.line .. ", ")
            if use.with then
                insert(code,"\t\t\twith = { " .. utils.implode_hashes(use.with) .. " }, ")
            end
            insert(code,"\t\t}")
        end
        insert(code,"\t}")
    end
    insert(code, "}\n")

    insert(code, "function _self.body(__, _context)")
    if self.extends then
        --insert(code, "\t_context = ...")
        insert(code, "\treturn " .. self.extends.value)
    elseif #self.body then
        --insert(code, "\t_context = ...")
        insert(code, "\t__:push_state(_self, 1)")
        for _, v in ipairs(self.body) do
            insert(code, "\t" .. v)
        end
        insert(code, "\t__:pop_state()")
    end
    insert(code, "end\n")

    if self.blocks then
        for n, b in pairs(self.blocks) do
            insert(code, "_self.blocks." .. n .. " = {")
            insert(code, "\tparent = " .. tostring(b.parent) .. ",")
            insert(code, "\tdesc = " .. quote_string(b.desc or "") .. ",")
            insert(code, "\tvars = " .. write(b.vars or {}, "\t") .. ",")
            insert(code, "}")
            insert(code, "function _self.blocks." .. n .. ".body(__, _context)")
            --insert(code, "\t_context = ...")
            for _, v in ipairs(b.code) do
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

--- Main parse function
--- @param source string the template source code
function compiler:parse(source)
    local l = 1
    local tag_pos = find(source, "{", l, true)
    local strip = false
    local open = {
        ["{{"] = tag_type.EXPRESSION,
        ["{%"] = tag_type.CONTROL,
        ["{#"] = tag_type.COMMENT,
    }
    self.body = {}
    self.code = {self.body}
    self.vars = {{}}
    self.macros = {}
    self.blocks = {}
    while tag_pos do
        if l <= tag_pos - 1 then -- cut text before tag
            local frag = sub(source, l, tag_pos - 1)
            self.line = self.line + strcount(frag, "\n")
            if strip then
                frag = lstrip(frag, strip)
                strip = nil
            end
            local wcp = strip_pattern[sub(source, tag_pos + 2, tag_pos + 2)]
            if wcp then -- checks if tag has space control
                frag = rstrip(frag, wcp)
            end
            if frag ~= "" then
                -- print("APPEND", frag)
                self:append_text(frag)
            end
        end
        local t, p = sub(source, tag_pos + 1, tag_pos + 1), tag_pos + 2
        if strip_pattern[sub(source, tag_pos + 2, tag_pos + 2)] then
            tag_pos = tag_pos + 1
        end
        if t == "{" then -- '{{'
            self.tag_type = tag_type.EXPRESSION
            local tok = tokenizer.new(sub(source, tag_pos + 2))
            local info = {}
            local expr = self:parse_expression(tok, info)
            self:append_expr(expr, info.raw)
            if tok:is_valid() then
                compiler_error(tok, "syntax", "expecting end of tag")
            end
            local path = tok:get_path_as_string()
            l = tag_pos + 2 + strlen(path) + strlen(tok.finish_token) -- start tag pos + '{{' +  tag length + '}}'
            self.line = self.line + strcount(path, "\n")
            strip = strip_pattern[sub(tok.finish_token, 1, 1)]
            tok = nil
        elseif t == "%" then -- '{%'
            self.tag_type = tag_type.CONTROL
            local tok = tokenizer.new(sub(source, tag_pos + 2))
            self.tag_name = tok:get_token()
            local tag_name = 'tag_' .. tok:get_token()
            if tags[tag_name] then
                self:append_code(tags[tag_name](self, tok:next())) -- call tags.tag_{{ name }}(compiler, tok)
                if tok:is_valid() then
                    compiler_error(tok, "syntax", "expecting end of tag")
                end
            else
                compiler_error(nil, "syntax", "unknown tag '" .. tok:get_token() .. "'")
            end
            local path = tok:get_path_as_string()
            l = tag_pos + 2 + strlen(path) + strlen(tok.finish_token) -- start tag pos + '{%' + tag length + '%}'
            self.line = self.line + strcount(path, "\n")
            strip = strip_pattern[sub(tok.finish_token, 1, 1)]
            tok = nil
            self.tag_name = nil
        elseif t == "#" then -- '{#'
            tag_pos = find(source, "#}", p, true)
            l = tag_pos + 2
        else
            tag_pos = tag_pos + 2
        end
        self.tag_type = nil
        while true do
            tag_pos = find(source, "{", tag_pos + 2, true)
            if not tag_pos then
                break
            end
            local delim = sub(source, tag_pos, tag_pos + 1)
            if open[delim] then
                break
            end
        end
        if self.ignore and tag_pos then
            while tag_pos do -- skip all tags until self.ignore tag
                if find(source, "^{%%[-~]?%s*" .. self.ignore, tag_pos) == tag_pos then
                    self.ignore = nil
                    break
                end
                tag_pos = find(source, "{", tag_pos + 1, true)
            end
        end
    end
    if #self.tags > 0  then
        local tag = self.tags[#self.tags]
        compiler_error(nil, "syntax", "Unexpected end of the template '" ..
            self.name .. "', expecting tag 'end" .. tag.name .. "' (opened on line " .. tag.line .. ")")
    end
    local frag = sub(source, l)
    if strip then
        frag = lstrip(frag, strip)
    end
    if frag ~= "" then
        self:append_text(frag)
    end
end

function compiler:parse_var_name(tok, opts)
    opts = opts or {}
    opts.var_system = false
    if tok:is_word() then
        local var = tok:get_token()
        if var == "_context" or var == "__" or var == "_self" then
            opts.var_system = true
        else
            opts.var_system = false
        end
        tok:next()
        return var
    else
        compiler_error(tok, "syntax", "expecting variable name")
    end
end

--- Parse basic variable name like:
--- one
--- one.two
--- one["two"].three
--- @param tok aspect.tokenizer
function compiler:parse_variable(tok)
    if tok:is_word() then
        local var, keys
        if tok:is('loop') then -- magick variable name {{ loop }}
            var = {"loop"}
            local tag, pos = self:get_last_tag('for')
            while tag do
                if tag.has_loop ~= true then
                    tag.has_loop = tag.has_loop or {}
                    local loop_key = tok:next():require("."):next():get_token()
                    if not loop_keys[loop_key] then
                        compiler_error(tok, "syntax", "expecting one of [" .. concat(tablex.keys(loop_keys), ", ") .. "]")
                    end
                    var[#var + 1] = '"' .. loop_key .. '"'
                    if loop_key == "parent" then
                        tag.has_loop.parent = true
                        tag, pos = self:get_last_tag('for', pos - 1)
                    else
                        tag.has_loop[loop_key] = true
                        tag = false
                    end
                end
                tok:next()
                --else
                --    tok:next()
                --    var = {"loop"}
            end
        --elseif tok:is("_context") then -- magick variable name {{ _context }}
        --    tok:next()
        --    var = {"_context"}
        end
        --if remember and not self.var_names[tok:get_token()] then
        --    self.var_names[tok:get_token()] = remember
        --end
        if not var then
            var = {self:parse_var_name(tok)}
            if not self:has_local_var(var[1]) then
                if self.stats then
                    if self.used_vars[var[1]] then
                        keys = self.used_vars[var[1]]
                        keys.where[#keys.where + 1] = {line = self.line, tag = self.tag_name}
                    else
                        keys = {where = {{line = self.line, tag = self.tag_name}}, keys = {}}
                        self.used_vars[var[1]] = keys
                    end
                end
                var[1] = "_context." .. var[1]
            end
        end
        while tok:is(".") or tok:is("[") do
            local mode = tok:get_token()
            tok:next()
            if tok:is_word() then
                if keys then
                    keys.keys[tok:get_token()] = 1
                    keys = nil
                end
                insert(var, '"' .. tok:get_token() .. '"')
                tok:next()
            elseif tok:is_string() then
                if keys then
                    keys.keys[tok:get_token()] = true
                    keys = nil
                end
                insert(var, tok:get_token())
                tok:next()
                if mode == "[" then
                    tok:require("]"):next()
                end
            else
                compiler_error(tok, "syntax", "expecting word or quoted string")
            end
        end
        if #var == 1 then
            return var[1]
        else
            return "__.v(" .. concat(var, ", ") .. ")"
        end
    else
        compiler_error(tok, "syntax", "expecting variable name")
    end
end

--- @param tok aspect.tokenizer
--- @param args_info table
--- @param assoc boolean returns table or values or list
function compiler:parse_args(tok, args_info, assoc, fname)
    local args, i = {}, 1
    if tok:is(")") then
        return args
    end
    while tok:is_valid() do
        local key, value, info, arg_info = nil, nil, {}, nil
        if tok:is_word() and tok:is_next("=") then
            key = tok:get_token()
            tok:next():require("="):next()
        end
        value = self:parse_expression(tok, info)
        if key then
            for _, arg in ipairs(args_info) do
                if arg.name == key then
                    arg_info = arg
                    break
                end
            end
            if not arg_info then
                compiler_error(tok, "compile", (fname or "callable") .. " has no '" .. key .. "' argument")
            end
        else
            if args_info[i] then
                arg_info = args_info[i]
            else
                compiler_error(tok, "compile", (fname or "callable") .. " has no argument #" .. i)
            end
        end
        if assoc then
            args[arg_info.name] = utils.cast_lua(value, info.type, args_info.type)
        else
            args[i] = utils.cast_lua(value, info.type, args_info.type)
        end
        i = i + 1
        if tok:is(",") then
            tok:next()
        else
            break
        end
    end
    return args
end

--- parse coma separated arguments
--- @param tok aspect.tokenizer
function compiler:parse_function(tok)
    local name, args
    if tok:is_word() then
        name = tok:get_token()
    else
        compiler_error(tok, "syntax", "expecting function name")
    end
    if not func.fn[name] then
        compiler_error(tok, "compile", "function " .. name .. "() not found")
    end
    tok:next():require("("):next()
    if func.args[name] then
        args = self:parse_args(tok, func.args[name], true, "function " .. name)
        tok:require(")"):next()
        if func.parsers[name] then
            return func.parsers[name](self, args)
        else
            return "__.fn." .. name .. "(__, {" .. utils.implode_hashes(args) .. "})"
        end
    elseif func.parsers[name] then
        local code = func.parsers[name](self, nil, tok)
        tok:require(")"):next()
        return code
    else
        tok:require(")"):next()
        return "__.fn." .. name .. "(__, {})"
    end
end

--- @param tok aspect.tokenizer
function compiler:parse_macro(tok)
    if tok:is("_self") then
        local name = tok:next():require("."):next():get_token()
        if not self.macros[name] then
            compiler_error(tok, "syntax", "Macro " .. name .. " not defined in this (" .. self.name .. ") template")
        end
        return "_self.macros." .. name .."(__, " .. self:parse_macro_args(tok:next():require("(")) .. ")", false
    elseif tok:is_word() then
        if tok:is_next(".") then
            local var = tok:get_token()
            if self.import[var] ~= import_type.GROUP then
                compiler_error(tok, "syntax", "Macro " .. var .. " not imported")
            end
            local name = tok:next():require("."):next():get_token()
            return "(" .. var .. "." .. name .. " and "
                    .. var .. "." .. name .. "(__, " .. self:parse_macro_args(tok:next()) .. "))", false
        elseif tok:is_next("(") then
            local name = tok:get_token()
            if self.import[name] ~= import_type.SINGLE then
                compiler_error(tok, "syntax", "Macro " .. name .. " not imported")
            end
            tok:next():require("(")
            return name .."(__, " .. self:parse_macro_args(tok) .. ")", false
        end
    end
end

--- Parse arguments for macros
--- @param tok aspect.tokenizer
function compiler:parse_macro_args(tok)
    tok:require("("):next()
    local i, args = 1, {}
    while true do
        local key, value = nil, nil
        if tok:is_word() then
            if tok:is_next("=") then
                key = tok:get_token()
                tok:next():require("="):next()
                value = self:parse_expression(tok)
            else
                value = self:parse_expression(tok)
            end
        else
            value = self:parse_expression(tok)
        end
        if key then
            args[ key ] = value
        else
            args[ i ] = value
        end
        if tok:is(",") then
            tok:next()
        else
            break
        end
        i = i + 1
    end
    tok:require(")"):next()
    args = utils.implode_hashes(args)
    if args then
        return "{ " .. args .. " }"
    else
        return "{}"
    end

end

--- Parse array (list or hash)
--- [1,2,3]
--- {"one": 1, "two": 2}
--- @param tok aspect.tokenizer
--- @param plain boolean return table without brackets
function compiler:parse_array(tok, plain)
    local vals = {}
    if tok:is("[") then
        tok:next()
        if tok:is("]") then
            return "{}"
        end
        while true do
            insert(vals, self:parse_expression(tok))
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
            tok:next()
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
                key = self:parse_expression(tok)
            end
            insert(vals, "[" .. key .. "] = " .. self:parse_expression(tok:require(":"):next()))
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
    if plain then
        return concat(vals, ", ")
    else
        return "{" .. concat(vals, ", ") .. "}"
    end
end

--- @param tok aspect.tokenizer
--- @return table
function compiler:parse_hash(tok)
    local hash = {}
    tok:require('{'):next()
    if tok:is("}") then
        tok:next()
        return hash
    end
    while true do
        local key
        if tok:is_word() then
            key = tok:get_token()
            tok:next()
        else
            compiler_error(tok, "syntax", "expecting hash key")
        end

        hash[key] = self:parse_expression(tok:require(":"):next())
        if tok:is(",") then
            tok:next()
        else
            break
        end
    end
    tok:require("}"):next()
    return hash
end

--- @param tok aspect.tokenizer
--- @param info table
--- @return string
function compiler:parse_filters(tok, var, info)
    info = info or {}
    info.raw = false
    while tok:is("|") do -- parse pipeline filter
        if tok:next():is_word() then
            local filter = tok:get_token()
            if not filters.fn[filter] then
                compiler_error(tok, "compile", "unknown filter " .. filter)
            end
            if filter == "raw" then
                info.raw = true
            end
            local args

            if tok:next():is("(") then
                args = self:parse_args(tok:next(), filters.info[filter].args, false, "filter " .. filter)
                tok:require(")"):next()
            end
            if info.type then
                var = utils.cast_lua(var, info.type, filters.info[filter].input)
            end
            if args then
                var = "__.f['" .. filter .. "'](" .. var .. ", " .. concat(args, ", ") .. ")"
            else
                var = "__.f['" .. filter .. "'](" .. var .. ")"
            end
            info.type = filters.info[filter].output
        else
            compiler_error(tok, "syntax", "expecting filter name")
        end
    end
    return var
end

--- Parse operand of the expression
--- @param tok aspect.tokenizer
--- @param info table
function compiler:parse_value(tok, info)
    local var
    info = info or {}
    info.type = nil
    info.raw = false
    if tok:is_word() then -- is variable name
        if special[tok:get_token()] then
            if tok:is("true") or tok:is("false") then -- is regular true/false/nil
                var = tok:get_token()
                tok:next()
                info.type = "boolean"
            elseif tok:is("null") or tok:is("nil") then -- is null
                var = 'nil'
                info.type = "nil"
                tok:next()
            else
                compiler_error(tok, "syntax", "unknown special token")
            end
        elseif tok:is_next("(") then
            if self.import[tok:get_token()] == import_type.SINGLE then
                var = self:parse_macro(tok)
                info.type = "nil"
            else
                var = self:parse_function(tok)
                info.type = "any"
            end
        elseif tok:is_seq{"word", ".", "word", "("} then
            var = self:parse_macro(tok)
            info.type = "nil"
        else
            var = self:parse_variable(tok)
            info.type = "any"
        end
    elseif tok:is_string() then -- is string or number
        var = tok:get_token()
        tok:next()
        info.type = "string"
    elseif tok:is_number() then
        var = tok:get_token()
        tok:next()
        info.type = "number"
    elseif tok:is("[") or tok:is("{") then -- is list or hash
        var = self:parse_array(tok)
        info.type = "table"
    elseif tok:is("(") then -- is expression
        local expr_info = {}
        var = self:parse_expression(tok:next(), expr_info)
        info.type = expr_info.type
        tok:require(")"):next()
        --if tok:is("|") then
        --    var = self:parse_filters(tok, var, info)
        --end
    else
        compiler_error(tok, "syntax", "expecting any value")
    end
    if tok:is("|") then
        var = self:parse_filters(tok, var, info)
    end
    return var
end

--- Parse any expression
--- @param tok aspect.tokenizer
--- @param opts table
function compiler:parse_expression(tok, opts)
    opts = opts or {}
    local expr = ast.new():parse(self, tok):pack()
    opts.type = expr.type
    opts.bracket = expr.bracket
    opts.raw = expr.raw
    return expr.value
end

--- @param tok aspect.tokenizer
--- @return table test information
function compiler:parse_is(tok)
    local test = {}
    if tok:require("is"):next():is('not') then
        test["not"] = true
        tok:next()
    end
    test.name = tok:get_token()
    tok:next()
    if tests.args[test.name] then
        if type(tests.args[test.name]) == "string" then -- has function: is divisible by(expr)
            tok:require(tests.args[test.name]):next()
            test.name = test.name .. "_" .. tests.args[test.name]
        end
        test.expr = self:parse_expression(tok:require("("):next())
        tok:next()
    end
    if not tests.fn["is_" .. test.name] then
        compiler_error(tok, "syntax", "expecting valid test name")
    end
    return test
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

function compiler:append_expr(lua, raw)
    local tag = self:get_last_tag()
    local line = self:get_checkpoint()
    local code = self.code[#self.code]
    if line then
        insert(code, line)
    end
    if lua then
        if tag and tag.append_expr then
            insert(code, tag.append_expr(tag, lua, raw))
        elseif raw then
            insert(code, "__(" .. lua .. ")")
        else
            insert(code, "__:e(" .. lua .. ")")
        end
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
    elseif lua then
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

--- Add local variable name to scope (used for includes and blocks)
--- @param name string
function compiler:push_var(name)
    if #self.tags > 0 then
        local tag = self.tags[#self.tags]
        if not tag.vars then
            tag.vars = {[name] = true}
        else
            tag.vars[name] = true
        end
    end
    local vars = self.vars[#self.vars]
    if not vars[name] then
        vars[name] = 1
    else
        vars[name] = vars[name] + 1
    end
end

--- Returns all variables name defined in the scope (without global)
--- @return table|nil list of variables like ["variable"] = variable
function compiler:get_local_vars()
    local vars = {}
    for k, _ in pairs(self.vars[#self.vars]) do
        vars[k] = k
    end

    if utils.nkeys(vars) > 0 then
        return vars
    else
        return nil
    end
end

--- Checks if local variable exists in current scope
--- @param name string
--- @return boolean
function compiler:has_local_var(name)
    return self.vars[ #self.vars ][name] ~= nil
end

--- Push the tag into scope stack
--- @param name string the tag name
--- @param code_space table|nil for lua code
--- @return aspect.tag
function compiler:push_tag(name, code_space, code_space_name, var_space)
    self.idx = self.idx + 1
    --- @type aspect.tag
    local tag = {
        id = self.idx,
        name = name,
        line = self.line
    }
    if code_space then
        insert(self.code, code_space)
        if not code_space_name then
            code_space_name = "nil"
        else
            code_space_name = quote_string(code_space_name)
        end
        code_space[#code_space + 1] = "__:push_state(_self, " .. self.line .. ", " .. code_space_name .. ")"
        self.prev_line = self.line
        tag.code_space_no = #self.code
    end
    tag.code_space = self.code[#self.code]
    tag.code_start_line = #tag.code_space
    if var_space then
        insert(self.vars, var_space)
        tag.var_space_no = #self.vars
        tag.used_vars = {}
    end
    tag.var_space = self.vars[#self.vars]

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
--- @return aspect.tag
function compiler:pop_tag(name)
    if #self.tags then
        --- @type aspect.tag
        local tag = self.tags[#self.tags]
        if tag.name == name then
            if tag.vars then -- pop variables
                local vars = self.vars[#self.vars]
                for var_name, _ in pairs(tag.vars) do
                    if vars[var_name] and vars[var_name] > 0 then
                        vars[var_name] = vars[var_name] - 1
                        if vars[var_name] == 0 then
                            vars[var_name] = nil
                        end
                    else
                        --utils.var_dump(var_name, vars, tag)
                        compiler_error(nil, "compiler", "broken variable scope")
                    end
                end
            end
            if tag.code_space_no then
                if tag.code_space_no ~= #self.code then -- dummy protection
                    compiler_error(nil, "compiler", "invalid code space layer in the tag " .. name)
                else
                    local prev = remove(self.code)
                    prev[#prev + 1] = "__:pop_state()"
                end
            end
            if tag.var_space_no then
                if tag.var_space_no ~= #self.vars then -- dummy protection
                    compiler_error(nil, "compiler", "invalid vars space layer in the tag " .. name)
                else
                    remove(self.vars)
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

--- Returns last tag from stack
--- @param name string if set then returns last tag with this name
--- @param from number|nil stack offset
--- @return aspect.tag
--- @return number|nil stack position
function compiler:get_last_tag(name, from)
    if name then
        if from and from < 1 then
            return nil
        end
        from = from or #self.tags
        if #self.tags > 0 then
            for i=from, 1, -1 do
                if self.tags[i].name == name then
                    return self.tags[i], i
                end
            end
        end
    elseif #self.tags then
        return self.tags[#self.tags], #self.tags
    end
    return nil
end

return compiler