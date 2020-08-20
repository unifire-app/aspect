local setmetatable = setmetatable
local tostring = tostring
local pairs = pairs
local type = type
local ipairs = ipairs
local find = string.find
local insert = table.insert
local remove = table.remove
local concat = table.concat
local next = next
local tokenizer = require("aspect.tokenizer")
local tags = require("aspect.tags")
local tests = require("aspect.tests")
local err = require("aspect.error")
local quote_string = require("aspect.utils").quote_string
local get_keys = require("aspect.utils").keys
local strcount = require("aspect.utils").strcount
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
--- @field ctx aspect.compiler.context|nil
--- @field append_text fun(tpl:aspect.compiler, text:string)
--- @field append_expr fun(tpl:aspect.compiler, expr:string)
--- @field append_code fun(tpl:aspect.compiler, code:string)

--- @class aspect.compiler.var_ref
--- @field name string
--- @field line number first use
--- @field keys table<string,number> key-name and line number of first usage

--- @class aspect.compiler.block
--- @field ctx aspect.compiler.context
--- @field parent boolean has parent function inside
--- @field desc string the description
--- @field start_line number
--- @field end_line number
--- @field start_pos number
--- @field end_pos number

--- @class aspect.compiler.macro
--- @field ctx aspect.compiler.context
--- @field args aspect.compiler.macro.arg[] list of used variables
--- @field desc string the description
--- @field start_line number of line there block started
--- @field end_line number of line there block ended

--- @class aspect.compiler.macro.arg
--- @field name string
--- @field default any

--- @class aspect.compiler.context
--- @field name string
--- @field code string[]
--- @field tpl_refs table<string, table>
--- @field var_refs table<string, aspect.compiler.var_ref>
--- @field vars table local variables

--- @class aspect.compiler
--- @field ctx_stack aspect.compiler.context[]
--- @field ctx aspect.compiler.context current context
--- @field aspect aspect.template
--- @field name string
--- @field blocks table<string, aspect.compiler.block> table of blocks
--- @field macros table<string, aspect.compiler.macro> table of macros with their code (witch array)
--- @field extends string|boolean if true then we has dynamic extend
--- @field import table
--- @field line number
--- @field prev_line number
--- @field tag_name string the current tag
--- @field ignore string|nil
--- @field tags aspect.tag[]
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
        ctx = nil,
        ctx_stack = {},
        name = name,
        line = 1,
        prev_line = 1,
        macros = {},
        extends = nil,
        blocks = {},
        uses = {},
        tags = {},
        idx  = 0,
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
    }
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
        insert(code, "\treturn " .. self.extends.value)
    elseif #self.ctx.code then
        insert(code, "\t__:push_state(_self, 1)")
        for _, v in ipairs(self.ctx.code) do
            insert(code, "\t" .. v)
        end
        insert(code, "\t__:pop_state()")
    end
    insert(code, "end\n")

    if self.blocks then
        for n, b in pairs(self.blocks) do
            insert(code, "function _self.blocks." .. n .. "(__, _context)")
            for _, v in ipairs(b.ctx.code) do
                insert(code, "\t" .. v)
            end
            insert(code, "end\n")
        end
    end

    if self.macros then
        for n, m in pairs(self.macros) do
            insert(code, "function _self.macros." .. n .. "(__, _context)")
            for _, v in ipairs(m.ctx.code) do
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
    -- found tag delimiter
    local delim = sub(source, tag_pos, tag_pos + 1)
    local open = {
        ["{{"] = tag_type.EXPRESSION,
        ["{%"] = tag_type.CONTROL,
        ["{#"] = tag_type.COMMENT,
    }
    self.ctx_stack = {}
    self.macros = {}
    self.blocks = {}
    -- create global context space
    self:start_context(true, true)
    while tag_pos do
        if open[delim] then
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
                    self:append_text(frag)
                end
            end
            local t, p = sub(source, tag_pos + 1, tag_pos + 1), tag_pos + 2
            if strip_pattern[sub(source, tag_pos + 2, tag_pos + 2)] then
                tag_pos = tag_pos + 1
            end
            if t == "{" then -- '{{'
                self.tag_type = tag_type.EXPRESSION
                local tok = tokenizer.new(source, tag_pos + 2)
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
                local tok = tokenizer.new(source, tag_pos + 2)
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
                local end_comment = find(source, "#}", p, true)
                self.line = self.line + strcount(sub(source, tag_pos, end_comment - 1), "\n")
                tag_pos = end_comment
                l = tag_pos + 2
            end
            self.tag_type = nil
        else
            tag_pos = tag_pos + 2
        end
        while true do
            tag_pos = find(source, "{", tag_pos + 2, true)
            if not tag_pos then
                break
            end
            delim = sub(source, tag_pos, tag_pos + 1)
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
    if #self.ctx_stack > 1 then
        compiler_error(nil, "syntax", "Unexpected extra contexts (" .. #self.ctx_stack .. ")")
    end
    self.ctx = self:end_context(self.ctx) -- finish last context
end

--- @param tok aspect.tokenizer
--- @param opts table
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
                        compiler_error(tok, "syntax", "loop-variable expects one of [" .. concat(get_keys(loop_keys), ", ") .. "] keys")
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
        elseif tok:is("_context") then -- magick variable name {{ _context }}
            tok:next()
        --    var = {"_context"}
        end
        local var_info
        if not var then
            var = {self:parse_var_name(tok)}
            var_info = self:touch_var(var[1])
            if not self.ctx.vars[var[1]] then
                var[1] = "_context." .. var[1]
            end
        else
            var_info = self:touch_var(var[1])
        end
        while tok:is(".") or tok:is("[") do
            local mode = tok:get_token()
            tok:next()
            if mode == "." then -- a.b
                insert(var, '"' .. tok:require_type('word'):get_token() .. '"')
                if var_info then
                    var_info.keys[tok:get_token()] = self.line
                end
                tok:next()
            elseif mode == "[" then -- a[b]
                insert(var, self:parse_expression(tok))
                tok:require("]"):next()
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
            if tok:next():is(".") then
                filter = filter .. "." .. tok:next():require_type("word"):get_token()
                tok:next()
            end
            if not filters.fn[filter] then
                compiler_error(tok, "compile", "unknown filter " .. filter)
            end
            if filter == "raw" then
                info.raw = true
            end
            local args

            if tok:is("(") then
                args = self:parse_args(tok:next(), filters.info[filter].args, false, "filter " .. filter)
                tok:require(")"):next()
            end
            if info.type then
                var = utils.cast_lua(var, info.type, filters.info[filter].input)
            end
            if args and #args > 0 then
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
    local code = self.ctx.code
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
    local code = self.ctx.code
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

--- Append any lua code
--- @param lua string
function compiler:append_code(lua)
    local tag = self:get_last_tag()
    local line = self:get_checkpoint()
    local code = self.ctx.code
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

--- Add ref to another template
--- @param name string template name
function compiler:add_template_ref(name)
    if not self.tag_name then
        return
    end
    if not self.ctx.tpl_refs[name] then
        self.ctx.tpl_refs[name] = { [self.tag_name] = self.line }
    elseif not self.ctx.tpl_refs[name][self.tag_name] then
        self.ctx.tpl_refs[name][self.tag_name] = self.line
    end
end

--- Add local variable name to scope (used for includes, blocks and macros)
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
    if not self.ctx.vars[name] then
        self.ctx.vars[name] = 1
    else
        self.ctx.vars[name] = self.ctx.vars[name] + 1
    end
end

--- Analyze and add variable ref if its global variable
--- @param name string template name
--- @return aspect.compiler.var_ref
function compiler:touch_var(name)
    if self.ctx.vars[name] then -- this is local variable
        return
    end
    if not self.ctx.var_refs[name] then
        self.ctx.var_refs[name] = {
            line = self.line,
            keys = {}
        }
    end
    return self.ctx.var_refs[name]
end

--- Returns all variable names defined in the scope (without global)
--- @return table|nil list of variables like ["variable"] = variable
function compiler:get_local_vars()
    local vars = {}
    for k, _ in pairs(self.ctx.vars) do
        vars[k] = k
    end
    if next(vars) then
        return vars
    else
        return nil
    end
end

--- Push the tag into scope stack
--- @param name string the tag name
--- @param create_context boolean|string if string, the string will be name of context
--- @param isolate_context boolean isolate variables and refs from previous context
--- @return aspect.tag
function compiler:push_tag(name, create_context, isolate_context)
    self.idx = self.idx + 1
    --- @type aspect.tag
    local tag = {
        id = self.idx,
        name = name,
        line = self.line,
        vars = {}
    }
    if create_context or isolate_context then
        tag.ctx = self:start_context(create_context, isolate_context)
    end
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
                local vars = self.ctx.vars
                for var_name, _ in pairs(tag.vars) do
                    if vars[var_name] and vars[var_name] > 0 then
                        vars[var_name] = vars[var_name] - 1
                        if vars[var_name] == 0 then
                            vars[var_name] = nil
                        end
                    else
                        compiler_error(nil, "compiler", "broken variable scope")
                    end
                end
            end
            if tag.ctx then
                self:end_context(tag.ctx)
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

--- Crate new context space for code, variables, refs ...
--- @param name boolean|string
--- @param isolate boolean
--- @return aspect.compiler.context
function compiler:start_context(name, isolate)
    --- @type aspect.compiler.context
    local ctx = {}
    ctx.id = #self.ctx_stack + 1
    if type(name) == "string" then
        ctx.name = name
        ctx.code = {
            "__:push_state(_self, " .. self.line .. ", " .. quote_string(ctx.name) .. ")"
        }
    elseif not name and ctx.id > 1 then
        ctx.code = self.ctx_stack[#self.ctx_stack].code
    else
        ctx.code = {}
    end
    if isolate then
        ctx.vars = {}
        ctx.tpl_refs = {}
        ctx.var_refs = {}
    elseif self.ctx then
        ctx.vars = self.ctx.vars
        ctx.tpl_refs = self.ctx.tpl_refs
        ctx.var_refs = self.ctx.var_refs
    end

    self.ctx_stack[ctx.id] = ctx
    self.ctx = ctx
    return ctx
end

--- @return aspect.compiler.context
function compiler:end_context(ctx)
    if ctx.id ~= self.ctx.id then -- just assert
        compiler_error(nil, "compiler", "incorrect termination of context")
    end
    if #self.ctx_stack > 0 then
        --- @type aspect.compiler.context
        local prev_ctx = remove(self.ctx_stack)
        if prev_ctx.name then
            insert(prev_ctx.code, "__:pop_state()")
        end
        self.ctx = self.ctx_stack[#self.ctx_stack]
        return prev_ctx
    else
        compiler_error(nil, "compiler", "broken context stack")
    end
end

return compiler