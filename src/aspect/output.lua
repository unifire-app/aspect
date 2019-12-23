local concat = table.concat
local remove = table.remove
local setmetatable = setmetatable
local getmetatable = getmetatable
--local print = print
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local tostring = tostring
local gsub = string.gsub
local len = string.len
local ngx = ngx or {}
local err = require("aspect.err")
local var_dump = require("aspect.utils").var_dump
local config = require("aspect.config")
local e_pattern = config.escape.pattern
local e_replaces = config.escape.replaces
local runtime_error = err.runtime_error
local is_false = config.is_false
local is_n = config.is_n
local is_empty_string = config.is_empty_string
local is_empty = table.isempty or function(v) return next(v) == nil end
local insert = table.insert
local tonumber = tonumber
local print = ngx.print or print
local flush = ngx.flush


--- @class aspect.output.parent
--- @field list table<aspect.template.block>
--- @field pos number
local _parents = {}

--- Output handler
--- @class aspect.output
--- @field data table runtime output fragments
--- @field line number
--- @field view aspect.view
--- @field stack table<aspect.view,number,string>
--- @field parents table<aspect.output.parent>
--- @field blocks table
--- @field opts table template options and helpers
--- @field result string template result
local output = {
    ipairs = ipairs,
    pairs = pairs,
    concat = table.concat,
    insert = table.insert,
    tonumber = tonumber,
    setmetatable = setmetatable
}

local function __tostring(self)
    return concat(self.data)
end

--- collect output
local mt_collect = {
    __call     = function (self, arg)
        self.data[#self.data + 1] = arg
    end,
    __tostring = __tostring,
    __index    = output,
}

--- print output
local mt_print = {
    __call     = function (_, arg)
        print(arg)
    end,
    __tostring = __tostring,
    __index    = output,
}

--- print output with buffering
local mt_chunked_print = {
    __call     = function (self, arg)
        self.size = self.size + len(arg)
        if self.size >= self.chink_size then
            print(concat(self.data) .. arg)
            if flush then
                flush(true)
            end
            self.data = {}
            self.size = 0
        else
            self.data[#self.data + 1] = arg
        end
    end,
    __tostring = __tostring,
    __index    = output,
}

--- call callback for output strings
local mt_call = {
    __call     = function (self, arg)
        self.p(arg)
    end,
    __tostring = __tostring,
    __index    = output,
}

--- call callback for output strings with buffer
local mt_chunked_call = {
    __call     = function (self, arg)
        self.size = self.size + len(arg)
        if self.size >= self.chink_size then
            self.p(concat(self.data) .. arg)
            self.data = {}
            self.size = 0
        else
            self.data[#self.data + 1] = arg
        end
    end,
    __tostring = __tostring,
    __index    = output,
}


function output.new(opt, ctx, options)
    local mt = mt_collect
    if options.print then
        if options.print == true then
            if options.size and options.size > 0 then
                mt = mt_chunked_print
            else
                mt = mt_print
            end
        else
            if options.size and options.size > 0 then
                mt = mt_chunked_call
            else
                mt = mt_call
            end
        end
    end
    return setmetatable({
        root = nil,
        view = nil,
        line = 0,
        data = {},
        stack = {},
        opts = opt,
        esc = opt.escape or false,
        chunk_size = options.chunk_size or false,
        p = options.print,
        f = opt.f,
        fn = opt.fn,
        blocks = {},
        ctx = ctx
    }, mt)
end

function output:set_print(p, size)
    if size and size == 0 then
        size = nil
    end
    self.p = p
    self.size = size
end

function output:push_state(view, line, scope_name)
    if #self.stack > self.opts.stack_size then
        runtime_error(self, "Call stack overflow (maximum " .. self.opts.stack_size .. ")")
    end
    if self.view then
        self.stack[#self.stack + 1] = {self.view, self.line, self.scope_name}
    end
    self.view = view
    self.line = line
    self.scope_name = scope_name
    return self
end

function output:pop_state()
    if #self.stack > 0 then
        local stack = remove(self.stack)
        self.view = stack[1]
        self.line = stack[2]
        self.scope_name = stack[3]
    else
        self.view = nil
        self.line = 0
        self.scope_name = nil
    end
    return self
end

--- Add block to runtime scope
--- @param view aspect.view
function output:add_blocks(view)
    if view.has_blocks then
        for n, b in pairs(view.blocks) do
            if not self.blocks[n] then
                self.blocks[n] = b
            elseif self.blocks[n].parent then
                local p
                if not self.parents then
                    self.parents = {}
                end
                if not self.parents[n] then
                    p = {
                        pos = 1,
                        list = {},
                        closed = false
                    }
                    self.parents[n] = p
                else
                    p = self.parents[n]
                end
                if not p.closed then
                    insert(p.list, b)
                end
                if not b.parent then -- if there is no parent () function in the parent block, stop collecting parent blocks
                    p.closed = true
                end
            end
        end
    end
end

function output:get_callstack()
    local callstack = {"begin"}
    for _, c in ipairs(self.stack) do
        if c[3] then
            callstack[#callstack + 1] = c[1].name .. ":" .. c[2] .. " " .. c[3]
        else
            callstack[#callstack + 1] = c[1].name .. ":" .. c[2]
        end
    end
    if self.scope_name then
        callstack[#callstack + 1] = (self.view and self.view.name or "<undef>") .. ":" .. self.line .. " " .. self.scope_name
    else
        callstack[#callstack + 1] = (self.view and self.view.name or "<undef>") .. ":" .. self.line
    end
    return "\t" .. concat(callstack, "\n\t")
end

--- Cast value to boolean
--- @param v any
--- @return boolean
function output.b(v)
    if not v or is_false[v] or is_false[getmetatable(v)] then
        return false
    elseif type(v) == "table" then
        local mt = getmetatable(v)
        if mt then
            if mt.__toboolean then
                return mt.__toboolean(v)
            elseif mt.__count  then
                return mt.__count(v) ~= 0
            end
        end
        if is_empty(v) then
            return nil
        end
    end
    return true
end

--- Returns value if cast value to boolean is true
--- @param v any
--- @return any|nil
function output.b2(v)
    if not v or is_false[v] or is_false[getmetatable(v)] then
        return nil
    elseif type(v) == "table" then
        local mt = getmetatable(v)
        if mt then
            if mt.__toboolean then
                return mt.__toboolean(v)
            elseif mt.__count  then
                return mt.__count(v) ~= 0
            end
        end
        if is_empty(v) then
            return nil
        end
    end
    return v
end

--- Cast value to string
--- @param v any
--- @return string
function output.s(v)
    if not v or is_empty_string[v] or is_empty_string[getmetatable(v)] then
        return ""
    else
        return tostring(v)
    end
end

--- Cast value to number
--- @param v any
--- @return number
function output.n(v)
    local typ = type(v)
    if typ == "number" then
        return v
    elseif typ == "string" then
        return tonumber(v) or 0
    elseif is_n[getmetatable(v)] then
        return v
    else
        return tonumber(tostring(v)) or 0
    end
end

function output.t(v)
    if type(v) == "table" then
        return v
    else
        return {}
    end
end

--- Cast value to the iterator (if possible)
function output.i(v)
    return v
end

--- Get iterator of the v
--- @param v any
--- @return fun iterator
--- @return any object
--- @return any key
function output.iter(v)
    local typ, mt = type(v), getmetatable(v)
    if typ == "table" then
        if mt and mt.__pairs then
            return mt.__pairs(v)
        else
            return pairs(v)
        end
    elseif mt and typ == "userdata" then
        if mt.__pairs then
            return mt.__pairs(v)
        end
    end

    return next, {}, nil
end

--- Get 'recursive' value from tables
--- @param v table|any
function output.v(v, ...)
    for _, k in ipairs({...}) do
        if type(v) ~= "table" then
            return nil
        end
        if v[k] == nil then
            return nil
        else
            v = v[k]
        end
    end
    return v
end

function output:e(v)
    if v == nil then
        return
    end
    if type(v) ~= "string" then
        v = output.s(v)
    end
    if self.esc then
        return self(gsub(v, e_pattern, e_replaces))
    else
        return self(v)
    end
end

function output:notice(msg)

end

--- Set autoescape
function output:autoescape(state)
    if state == nil then
        return
    end
    if self.esc ~= state then
        self.esc = state
        return not state
    end
end

function output:get_view(name)
    return self.opts.get(name)
end

function output:finish()
    if not self.result then
        self.result = concat(self.data)
        self.data = nil
    end
    return self
end

return output