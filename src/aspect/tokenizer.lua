--local lexer = require("aspect.lexer")
local compiler_error = require("aspect.err").compiler_error
local strcount = require("pl.stringx").count
local setmetatable = setmetatable
local insert = table.insert
local concat = table.concat
local strlen = string.len
local lexer = require("pl.lexer")
local yield = coroutine.yield
local tonumber = tonumber
local patterns = require("aspect.config").tokenizer.patterns
local compiler = require("aspect.config").compiler
local utils = require("aspect.utils")

--- @class aspect.tokenizer
--- @field tok function
--- @field token any
--- @field typ string
local tokenizer = {}
local mt = {__index = tokenizer}

local function tdump(tok)
    return yield(tok,tok)
end

local function ndump(tok,options)
    if options and options.number then
        tok = tonumber(tok)
    end
    return yield("number",tok)
end

-- regular strings, single or double quotes; usually we want them
-- without the quotes
local function sdump(tok, options)
    if options and options.string then
        tok = tok:sub(2,-2)
    end
    return yield("string",tok)
end

local function wsdump (tok)
    return yield("space", tok)
end

local function wdump(tok)
    return yield("word",tok)
end

local function tstop(tok)
    return yield("stop",tok)
end

local straight = {
    "word",
    "string",
    "number"
}

local matches = {
    {patterns.WSPACE,wsdump},
    {patterns.NUMBER3,ndump},
    {patterns.WORD, wdump},
    {patterns.NUMBER4,ndump},
    {patterns.NUMBER5,ndump},
    {patterns.STRING1,sdump},
    {patterns.STRING2,sdump},
    {patterns.STRING3,sdump},
    {'^}}',tstop},
    {'^%%}',tstop},
    {'^%-}}',tstop},
    {'^%-%%}',tstop},
    {'^==',tdump},
    {'^!=',tdump},
    {'^%?:',tdump},
    {'^%?%?',tdump},
    {'^<=',tdump},
    {'^>=',tdump},
    {'^%*%*',tdump},
    {'^//',tdump},
    {'^.',tdump}
}


--- Start the tokenizer
--- @return aspect.tokenizer
function tokenizer.new(s)
    local tokens = {}
    local indent
    local parsed_len = 0
    local finished_token
    local tok = lexer.scan(s, matches, {space=true}, {number=true,string=false})
    for tok_type, token in tok do
        if tok_type == "stop" then
            parsed_len = parsed_len + strlen(token)
            finished_token = token
            break
        end
        if tok_type == "space" then
            if tokens[#tokens] then
                tokens[#tokens][3] = token
            else
                indent = token
            end
        else
            parsed_len = parsed_len + strlen(token)
            tokens[#tokens + 1] = {tok_type, token}
        end
    end
    return setmetatable({
        tokens = tokens,
        i = 1,
        token = tokens[1][2],
        typ = tokens[1][1],
        finish_token = finished_token,
        parsed_len = parsed_len,
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
    --utils.var_dump("NEXT" .. tostring(self.tokens[self.i - 1][2]) .. " => " .. tostring((self.tokens[self.i] or {})[2]))
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
    if self.token and compiler.boolean[self.token:lower()] then
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