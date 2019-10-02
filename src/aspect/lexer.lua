local lexer = require("pl.lexer")
local yield = coroutine.yield
local tonumber = tonumber

local NUMBER1 = '^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+'
local NUMBER2 = '^[%+%-]?%d+%.?%d*'
local NUMBER3 = '^0x[%da-fA-F]+'
local NUMBER4 = '^%d+%.?%d*[eE][%+%-]?%d+'
local NUMBER5 = '^%d+%.?%d*'
local IDEN = '^[%a_][%w_]*'
local WSPACE = '^%s+'
local STRING1 = "^(['\"])%1" -- empty string
local STRING2 = [[^(['"])(\*)%2%1]]
local STRING3 = [[^(['"]).-[^\](\*)%2%1]]
local CHAR1 = "^''"
local CHAR2 = [[^'(\*)%1']]
local CHAR3 = [[^'.-[^\](\*)%1']]
local PREPRO = '^#.-[^\\]\n'

local lex = {}

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
    if lex.keyword[tok] then
        return yield("keyword",tok)
    else
        return yield("iden",tok)
    end
end

local function tstop(tok)
    return yield("stop",tok)
end

lex.tokens = {

}

lex.keyword =  {
    ["if"] = true, ["elseif"] = true, ["else"] = true, ["endif"] = true,
    ["for"] = true, ["in"] = true, ["elsefor"] = true, ["endfor"] = true,
    ["set"] = true, ["endset"] = true,
    ["true"] = true, ["false"] = true, ["null"] = true, ["nil"] = true,
    ["apply"] = true, ["endapply"] = true,
    ["extends"] = true, ["block"] = true, ["endblock"] = true,
    ["autoescape"] = true, ["endautoescape"] = true,
    ["in"] = true, ["is"] = true,
    ["macro"] = true, ["endmacro"] = true, ["from"] = true,
    ["and"] = true, ["or"] = true,  ["not"] = true,
    ["include"] = true, ["import"] = true,
}

lex.stop_tokens = {
    ["}}"] = true, ["*}"] = true, ["%}"] = true
}

lex.matches = {
    {WSPACE,wsdump},
    {NUMBER3,ndump},
    {IDEN,tpl_vdump},
    {NUMBER4,ndump},
    {NUMBER5,ndump},
    {STRING1,sdump},
    {STRING2,sdump},
    {STRING3,sdump},
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

function lex.tokenize(code)
    return lexer.scan(code, lex.matches, {space=true}, {number=true,string=false})
end

return lex