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

local function tpl_vdump(tok)
    return yield("iden",tok)
end

local function tstop(tok)
    return yield("stop",tok)
end

local matches = {
    {patterns.WSPACE,wsdump},
    {patterns.NUMBER3,ndump},
    {patterns.IDEN,tpl_vdump},
    {patterns.NUMBER4,ndump},
    {patterns.NUMBER5,ndump},
    {patterns.STRING1,sdump},
    {patterns.STRING2,sdump},
    {patterns.STRING3,sdump},
    {'^}}',tstop},
    {'^%%}',tstop},
    {'^==',tdump},
    {'^!=',tdump},
    {'^<=',tdump},
    {'^>=',tdump},
    {'^%*%*',tdump},
    {'^%.%.%.',tdump},
    {'^%.%.',tdump},
    {'^.',tdump}
}


--- Start the tokenizer
--- @return aspect.tokenizer
function tokenizer.new(s)
    local tok = lexer.scan(s, matches, {space=true}, {number=true,string=false})
    local itself = setmetatable({
        count = 0,
        path = {},
        tok = tok,
        token = nil,
        typ = nil
    }, mt)
    return itself:next()
end

function tokenizer:get_pos()
    return #self.path
end

--- Returns the token value
--- @return string
function tokenizer:get_token()
    return self.token
end

--- Returns the token type
--- @return string
function tokenizer:get_token_type()
    return self.typ
end

--- Returns tokenized fragments as string
--- @return string
function tokenizer:get_path_as_string()
    return concat(self.path)
end

--- @return aspect.tokenizer
function tokenizer:next()
    while true do
        if self.typ == "stop" then
            break
        end
        self.typ, self.token = self.tok()
        insert(self.path, self.token)
        if not self.typ then
            self.typ = "stop"
            break
        end
        if self.typ ~= "space" then
            self.count = self.count + 1
            break
        end
    end
    return self
end

--- Checks the token value
--- @return boolean
function tokenizer:is(token)
    return self.token == token
end

--- Checks the token value and if token value incorrect throw an error
--- @return aspect.tokenizer
function tokenizer:require(token)
    if self.token ~= token then
        compiler_error(self, "syntax", "expecting '" .. token .. "'")
    end
    return self
end

--- Checks if the token is simple word
--- @return boolean
function tokenizer:is_word()
    return self.typ == "iden"
end

--- Checks if the token is scalar value
--- @return boolean
function tokenizer:is_value()
    return self.typ == "string" or self.typ == "number"
end

--- Checks if the token is string
--- @return boolean
function tokenizer:is_string()
    return self.typ == "string"
end

--- Checks if the token is number
--- @return boolean
function tokenizer:is_number()
    return self.typ == "number"
end

--- Checks if the token is valid (stream not finished)
--- @return boolean
function tokenizer:is_valid()
    return self.typ and self.typ ~= "stop"
end

return tokenizer