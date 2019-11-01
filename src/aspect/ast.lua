local dump = require("pl.pretty").dump

--- Intermediate branch element
--- @class aspect.ast.node
--- @field op aspect.ast.op
--- @field c aspect.ast.node|aspect.ast.leaf|nil condition for ternary operator
--- @field l aspect.ast.node|aspect.ast.leaf left node or leaf
--- @field r aspect.ast.node|aspect.ast.leaf right node or leaf
--- @field p aspect.ast.node|nil parent node
--- @field pos number token position
local _node = {}

--- Leaf - node with value. Branch finite element
--- @class aspect.ast.leaf
--- @field type string type of leaf (numeric, string, variable, expr, table)
--- @field value string value of the leaf
--- @field pos number token position
local _leaf = {}

--- The operator settings
--- @class aspect.ast.op
--- @field order number
--- @field name string
--- @field type string
--- @field c string|nil
--- @field l string|nil
--- @field r string
--- @field out string
local _op = {}

--- AST builder
--- @class aspect.ast
--- @field current aspect.ast.node|aspect.ast.leaf
local ast = {}

--- @type table<aspect.ast.op>
local ops_unary
local ops_binary
local ops_ternary
local mt = {__index = ast}

function ast.new()
    if not ops_binary then
        ops_unary = {}
        ops_binary = {}
        ops_ternary = {}
        for _, op in ipairs(require("aspect.config").compiler.ops) do
            if op.type == "unary" then
                ops_unary[op.name] = op
            elseif op.type == "binary" then
                ops_binary[op.name] = op
            elseif op.type == "ternary" then
                ops_ternary[op.name] = op
            end
        end
    end

    return setmetatable({
        current = nil,
    }, mt)
end

--- @param compiler aspect.compiler
--- @param tok aspect.tokenizer
function ast:parse(compiler, tok)
    do
        local info = {}
        self.current = {
            value = compiler:parse_value(tok, info),
            type = info.type
        }
    end
    while tok:is_valid() do
        local token, token_pos = tok:get_token(), tok:get_pos()
        tok:next()
        if ops_binary[token] then
            local op, info = ops_binary[token], {}
            --print("PREPARE " .. token)
            local leaf = {
                value = compiler:parse_value(tok, info),
                type = info.type,
                pos = tok:get_pos()
            }
            if self.current.value then -- first element of the tree
                self:insert(op, leaf, token_pos)
            elseif self.current.op.order <= op.order then
                --print("push (<=) " .. op.name)
                while self.current.p and self.current.op.order < op.order do
                    --print("MOVE UP")
                    self:up()
                end
                self:insert(op, leaf, token_pos)
            else -- self.current.op.order > op.order
                --print("push (>) " .. op.name)
                while self.current.r.op and self.current.op.order > op.order do -- just in case
                    --print("MOVE DOWN")
                    self:down()
                end
                self:fork(op, leaf, token_pos)
            end
        end
    end
end

--- Insert new node in the current branch
--- @param op aspect.ast.op
--- @param r aspect.ast.leaf
--- @param pos number
function ast:insert(op, r, pos)
    --print("INSERT " .. r.value)
    local parent = self.current.p
    self.current = {
        p = parent,
        op = op,
        pos = pos,
        l = self.current,
        r = r
    }
    if parent then
        parent.r = self.current
    end
    if self.current.l.op then
        self.current.l.p = self.current
    end
end

--- Insert new node and create new branch
--- @param op aspect.ast.op
--- @param r aspect.ast.leaf
--- @param pos number
function ast:fork(op, r, pos)
    --print("FORK " .. r.value)
    local current_r = self.current.r
    self.current.r = {
        p = self.current,
        op = op,
        pos = pos,
        l = current_r,
        r = r
    }
    if self.current.r.l.op then
        self.current.r.l.p = self.current.r
    end
    self.current = self.current.r
end

--- Move pointer to up of tree (by nodes)
function ast:up()
    if self.current.p then
        self.current = self.current.p
    end
    return self
end

--- Move pointer to down of tree (by nodes)
function ast:down()
    if self.current.r and not self.current.value then
        self.current = self.current.r
    end
    return self
end

function ast:get_tail()
    local node = self.root
    while node.r and node.r.r do
        node = node.r
    end
    return node
end

local function dump_visit(node, indent)
    local out = {}
    if node.op then -- if aspect.ast.node
        table.insert(out, "\n" .. indent .. "OP " .. node.op.name)
        if node.l then
            table.insert(out, indent .. "l: " .. dump_visit(node.l, indent .. "    "))
        end
        if node.r then
            table.insert(out, indent .. "r: " .. dump_visit(node.r, indent .. "    "))
        end
    else -- if aspect.ast.leaf
        table.insert(out, node.type .. "(" .. node.value .. ")")
    end

    return table.concat(out, "\n")
end

--- @return string
function ast:dump()
    local root = self.current
    while root.p do
        root = root.p
    end
    --dump(root)
    return dump_visit(root, "")
end

local function visit(node, callback)
    if node.op then -- if aspect.ast.node
        local left, right, cond = node.l, node.r, node.c
        if left.op then
            left = visit(left, callback)
        end
        if right and right.op then
            right = visit(right, callback)
        end
        if cond and cond.op then
            cond = visit(cond, callback)
        end
        --assert(left.value, "left leaf of node is not leaf")
        --assert(right.value, "right leaf of node is not leaf")
        return {
            value = callback(node.op, left, right, cond),
            type = node.op.out
        }
    else -- is leaf
        return node.value, node.type
    end

end

function ast:pack(callback)
    local root = self.current
    while root.p do
        root = root.p
    end
    return visit(root, callback)
end

return ast