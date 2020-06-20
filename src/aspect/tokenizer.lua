local compiler_error = require("aspect.error").compiler_error
local setmetatable = setmetatable
local concat = table.concat
local strlen = string.len
local tonumber = tonumber
local patterns = require("aspect.config").tokenizer.patterns
local compiler = require("aspect.config").compiler
local utils = require("aspect.utils")
local starts_with = utils.starts_with
local strfind = string.find
local strsub = string.sub
local ipairs = ipairs

--- Information about the token
--- 1 - token type
--- 2 - token string
--- 3 - whitespace after token
--- @class aspect.tokenizer.token

--- @class aspect.tokenizer
--- @field tokens table
--- @field token function
--- @field token any
--- @field parsed_len number
local tokenizer = {}
local mt = {__index = tokenizer}

local function unquote(tok)
    return tok:sub(2,-2)
end

local straight = {
    "word",
    "string",
    "number"
}

local matches = {
    -- pattern          type       sanitizer   strict
    {patterns.WSPACE,   "space",   nil,       false},
    {patterns.NUMBER3,  "number",  tonumber,  false},
    {patterns.WORD,     "word",    nil,       false},
    {patterns.NUMBER4,  "number",  tonumber,  false},
    {patterns.NUMBER5,  "number",  tonumber,  false},
    {patterns.STRING1,  "string",  unquote,   false},
    {patterns.STRING2,  "string",  unquote,   false},
    {patterns.STRING3,  "string",  unquote,   false},
    {'}}',              "stop",    nil,       true },
    {'%}',              "stop",    nil,       true },
    {'-}}',             "stop",    nil,       true },
    {'-%}',             "stop",    nil,       true },
    {'==',              nil,       nil,       true },
    {'!=',              nil,       nil,       true },
    {'?:',              nil,       nil,       true },
    {'??',              nil,       nil,       true },
    {'<=',              nil,       nil,       true },
    {'>=',              nil,       nil,       true },
    {'**',              nil,       nil,       true },
    {'/',               nil,       nil,       true },
    {'^.',              nil,       nil,       false }
}

--- Start the tokenizer
--- @param s string input string
--- @return aspect.tokenizer
function tokenizer.new(s, start)
    local tokens = {}
    local indent, final_token
    local parsed_len = 0
    local idx, resume = start or 1, true
    while idx <= #s and resume do
        for _,m in ipairs(matches) do
            local typ, tok = m[2]
            local i1, i2
            if m[4] then
                if starts_with(s,m[1],idx) then
                    tok = m[1]
                    i2 = idx + #tok - 1
                end
            else
                i1, i2 = strfind(s,m[1],idx)
                if i1 then
                    tok = strsub(s,i1,i2)
                end
            end
            if tok then
                if not typ then
                    typ = tok
                end
                idx = i2 + 1
                parsed_len = parsed_len + strlen(tok)
                if typ == "stop" then
                    final_token = tok
                    resume = false
                    break
                elseif typ == "space" then
                    if tokens[#tokens] then
                        tokens[#tokens][3] = tok
                    else
                        indent = tok
                    end
                else
                    tokens[#tokens + 1] = {typ, tok}
                end
                break
            end
        end
    end
    return setmetatable({
        tokens = tokens,
        i = 1,
        token = tokens[1][2],
        typ = tokens[1][1],
        finish_token = final_token,
        parsed_len = parsed_len,
        start = start or 1,
        indent = indent
    }, mt)
end

function tokenizer:get_pos()
    return self.i
end

--- Returns the token value
--- @return string
function tokenizer:get_token()
    return self.token
end

--- Returns the next token value
--- @return string
function tokenizer:get_next_token()
    if self.tokens[self.i + 1] then
        return self.tokens[self.i + 1][2]
    end
end

--- Returns the token type
--- @return string
function tokenizer:get_token_type()
    return self.typ
end

--- Returns the next token type
--- @return string
function tokenizer:get_next_token_type()
    if self.tokens[self.i + 1] then
        return self.tokens[self.i + 1][1]
    end
end

--- Returns done tokens as string
--- @param from number by default — 1
--- @param to number by default — self.i
--- @return string
function tokenizer:get_path_as_string(from, to)
    local path = {self.indent}
    from = from or 1
    to = to or self.i
    for i = from, to do
        if self.tokens[i] then
            path[#path + 1] = self.tokens[i][2] .. (self.tokens[i][3] or "")
        end
    end
    return concat(path)
end

--- @return aspect.tokenizer
function tokenizer:next()
    if not self.tokens[self.i] then
        return self
    end
    self.i = self.i + 1
    if self.tokens[self.i] then
        self.token = self.tokens[self.i][2]
        self.typ = self.tokens[self.i][1]
    else
        self.token = nil
        self.typ = nil
    end
    return self
end

--- Checks the token value
--- @return boolean
function tokenizer:is(token)
    return self.token == token
end

--- Checks the next token value
--- @return boolean
function tokenizer:is_next(token)
    return self:get_next_token() == token
end

--- Checks sequence of tokens (current token - start of the sequence)
--- @param seq table
--- @return boolean
--- @return string name of sequence there failed
function tokenizer:is_seq(seq)
    for i=0,#seq-1 do
        if not self.tokens[self.i + i] then
            return false, seq[i + 1]
        end
        if self.tokens[self.i + i][1] ~= seq[i + 1] then
            return false, seq[i + 1]
        end
    end
    return true
end

--- Checks the token value and if token value incorrect throw an error
--- @param token string
--- @return aspect.tokenizer
function tokenizer:require(token)
    if self.token ~= token then
        compiler_error(self, "syntax", "expecting '" .. token .. "'")
    end
    return self
end


--- Checks the token type and if token type incorrect throw an error
--- @param typ string
--- @return aspect.tokenizer
function tokenizer:require_type(typ)
    if self.typ ~= typ then
        compiler_error(self, "syntax", "expecting of " .. typ .. " type token")
    end
    return self
end

--- Checks if the token is simple word
--- @return boolean
function tokenizer:is_word()
    return self.typ == "word"
end

--- @return boolean
function tokenizer:is_boolean()
    if self.token and compiler.is_boolean[self.token:lower()] then
        return true
    end
    return false
end

--- Checks if the next token is simple word
--- @return boolean
function tokenizer:is_next_word()
    return self:get_next_token_type() == "word"
end

--- Checks if the token is scalar value
--- @return boolean
function tokenizer:is_value()
    return self.typ == "string" or self.typ == "number"
end

--- Checks if the next token is scalar value
--- @return boolean
function tokenizer:is_next_value()
    local typ = self:get_next_token_type()
    return typ == "string" or typ == "number"
end

--- Checks if the token is string
--- @return boolean
function tokenizer:is_string()
    return self.typ == "string"
end

--- Checks if the next token is string
--- @return boolean
function tokenizer:is_next_string()
    return self:get_next_token_type() == "string"
end

--- Checks if the token is number
--- @return boolean
function tokenizer:is_number()
    return self.typ == "number"
end

--- Checks if the next token is number
--- @return boolean
function tokenizer:is_next_number()
    return self:get_next_token_type() == "number"
end

function tokenizer:is_op()
    return self.typ and not straight[self.typ]
end

function tokenizer:is_next_op()
    return self.tokens[self.i + 1] and not straight[self.tokens[self.i + 1][1]]
end

--- Checks if the token is valid (stream not finished)
--- @return boolean
function tokenizer:is_valid()
    return self.typ ~= nil
end

return tokenizer