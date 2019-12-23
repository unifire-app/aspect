local setmetatable = setmetatable
local error = error
local type = type
local traceback = debug.traceback

--- @class aspect.error
--- @field code string
--- @field line number
--- @field name string
--- @field message string
--- @field callstack string
--- @field traceback string
--- @field context string
local err = {
    _NAME = "error"
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
    if e.callstack then
        msg = msg .. "\nCallstack:\n" .. e.callstack
    end
    if e.traceback then
        msg = msg .. "\nLua " .. e.traceback
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
        if code == "syntax" then
            if tok:is_valid() then
                fields.message = "unexpected token '" .. tok:get_token() .. "', " .. message
            else
                fields.message = "unexpected end of tag, " .. message
            end
        else
            fields.message = message
        end
        fields.context = tok:get_path_as_string()
    else
        fields.message = message
    end
    error(fields)
end

--- @param __ aspect.output
--- @param message string|aspect.error
function err.runtime_error(__, message)
    error(err.new_runtime(__, message))
end

function err.is(wtf)
    return type(wtf) == "table" and wtf._NAME == "error"
end

--- @param __ aspect.output
--- @param e aspect.error|string|table
function err.new_runtime(__, e)
    if not err.is(e) then
        e = err.new(e, "runtime")
    end
    e:set_name(__.name, __.line, __:get_callstack())
    return e
end

function err.new(e, code)
    if type(e) ~= 'table' then
        e = tostring(e)
        e = {
            message = e,
        }
    elseif e._NAME == "error" then
        return e
    end


    return setmetatable({
        code = e.code or code or "internal",
        line = e.line or 0,
        name = e.name or "runtime",
        message = e.message,
        callstack = nil,
        traceback = e.traceback or traceback(),
        context = e.context,
    }, mt)
end

function err:set_code(code)
    self.code = code
    return self
end

function err:set_name(name, line, callstack)
    self.name = name
    self.line = line
    self.callstack = callstack
    return self
end

function err:get_message()
    return self.message
end


return err