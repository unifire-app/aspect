local setmetatable = setmetatable
local error = error
local type = type
local traceback = debug.traceback

--- @class aspect.error
--- @field code string
--- @field line number
--- @field name string
--- @field message string
--- @field traceback string
--- @field context string
local err = {
    _ = "error"
}

--- @param e aspect.error
local function to_string(e)
    local msg
    if e.name then
        msg = e.code .. " error: " .. e.message .. " in " .. e.name .. ":" .. e.line
    else
        msg = e.code .. " error: " .. e.message
    end
    if e.context then
        msg = msg .. "\nContext: " .. e.context .. " <-- there"
    end
    if e.traceback then
        msg = msg .. "\n" .. e.traceback
    end
    return msg
end

local mt = {
    __index = err,
    __tostring = to_string
}

--- @param tok aspect.tokenizer
--- @param code string
--- @param message string
function err.compiler_error(tok, code, message)
    local fields = {
        code = code,
        traceback = traceback(),
    }
    if tok then
        if tok:is_valid() then
            fields.message = "unexpected token '" .. tok:get_token() .. "', " .. message
        else
            fields.message = "unexpected end of tag, " .. message
        end
        fields.context = tok:get_path_as_string()
    else
        fields.message = message
    end
    error(fields)
end

function err.new(fields)
    if type(fields) == 'string' then
        fields = {
            message = fields,
        }
    end

    return setmetatable({
        code = fields.code or "internal",
        line = fields.line or 0,
        name = fields.name or "runtime",
        message = fields.message,
        traceback = fields.traceback or traceback(),
        context = fields.context,
    }, mt)
end

function err:set_name(name, line)
    self.name = name
    self.line = line
    return self
end


return err