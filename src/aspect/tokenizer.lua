local lexer = require("aspect.lexer")
local compiler_error = require("aspect.err").compiler_error
local strcount = require("pl.stringx").count
local setmetatable = setmetatable
local insert = table.insert
local concat = table.concat
local strlen = string.len

--- @class aspect.tokenizer
--- @field tok function
--- @field token any
--- @field typ string
local tokenizer = {}
local mt = {__index = tokenizer}

function tokenizer.new(s)
    local tok = lexer.tokenize(s)
    local itself = setmetatable({
        path = {},
        tok = tok,
        token = nil,
        typ = nil
    }, mt)
    return itself:next()
end

function tokenizer:get_token()
    return self.token
end

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
        if not self.typ or self.typ ~= "space" then
            break
        end
    end
    return self
end

function tokenizer:is(token)
    return self.token == token
end

function tokenizer:require(token)
    if self.token ~= token then
        compiler_error(self, "syntax", "expecting '" .. token .. "'")
    end
    return self
end

function tokenizer:is_keyword()
    return self.typ == "keyword"
end

function tokenizer:is_word()
    return self.typ == "iden"
end

--- @return string
function tokenizer:is_value()
    return self.typ == "string" or self.typ == "number"
end

function tokenizer:is_string()
    return self.typ == "string"
end

function tokenizer:is_number()
    return self.typ == "number"
end

function tokenizer:is_valid()
    return self.typ and self.typ ~= "stop"
end

return tokenizer