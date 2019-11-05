local insert = table.insert
local concat = table.concat
local setmetatable = setmetatable
local ipairs = ipairs
local require = require

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

--- AST builder
--- @class aspect.ast
--- @field current aspect.ast.node|aspect.ast.leaf
local ast = {}

--- @type table<aspect.ast.op>
local ops_unary
local ops
local mt = {__index = ast}

function ast.new()
    if not ops then
        ops_unary = {}
        ops = {}
        for _, op in ipairs(require("aspect.ast.ops")) do
            if type(op.token) == "table" then
                for _, token in ipairs(op.token) do
                    if op.type == "unary" then
                        ops_unary[token] = op
                    else
                        ops[token] = op
                    end
                end
            else
                if op.type == "unary" then
                    ops_unary[op.token] = op
                else
                    ops[op.token] = op
                end
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
        local info, unary_op, leaf = {}, ops_unary[tok:get_token()]
        if unary_op then
            tok:next()
        end
        if tok:is("(") then
            leaf = {
                value = "(" .. compiler:parse_expression(tok:next(), info) .. ")",
                type = info.type,
                bracket = true
            }
            tok:require(")"):next()
        else
            leaf = {
                value = compiler:parse_value(tok, info),
                type = info.type,
                bracket = false
            }
        end
        if unary_op then
            self.current = {
                op = unary_op,
                l = nil,
                r = leaf
            }
        else
            self.current = leaf
        end
    end
    while tok:is_valid() do
        local token, sub_ast = tok:get_token(), nil
        local op, op_unary, info = ops[token], nil, {}
        if not op then
            break
        end
        if op.type == "ternary" then
            local sub_tree = ast.new()
            sub_ast = sub_tree:parse(compiler, tok:next()):get_root()
            tok:require(op.delimiter)
        end
        tok:next()
        if ops_unary[tok:get_token()] then -- has unary operator ('-' or 'not')
            op_unary = ops_unary[tok:get_token()]
            tok:next()
        end
        local leaf
        if tok:is("(") then
            leaf = {
                value = "(" .. compiler:parse_expression(tok:next(), info) .. ")",
                type = info.type,
                bracket = true
            }
            tok:require(")"):next()
        else
            leaf = {
                value = compiler:parse_value(tok, info),
                type = info.type,
                bracket = false
            }
        end
        if self.current.value then -- first element of the tree
            self:insert(op, leaf)
        elseif self.current.op.order <= op.order then
            --print("push (<=) " .. op.name)
            while self.current.p and self.current.op.order < op.order do
                --print("MOVE UP")
                self:up()
            end
            self:insert(op, leaf)
        else -- self.current.op.order > op.order
            --print("push (>) " .. op.name)
            while self.current.r.op and self.current.op.order > op.order do -- just in case
                --print("MOVE DOWN")
                self:down()
            end
            self:fork(op, leaf)
        end
        if op.type == "ternary" and sub_ast then
            self.current.c = self.current.l
            self.current.l = sub_ast
            sub_ast.p = self.current
        end
        if op_unary then
            self:fork(op_unary, nil)
        end
    end
    return self
end

--- Insert new node in the current branch
--- @param op aspect.ast.op
--- @param r aspect.ast.leaf
function ast:insert(op, r)
    --print("INSERT " .. r.value)
    local parent = self.current.p
    self.current = {
        p = parent,
        op = op,
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
--- @param r aspect.ast.leaf|nil if nil - unary operator, just create new branch with current leaf
function ast:fork(op, r)
    --print("BEGIN FORK FOR", op.name, op.type)
    local current_r = self.current.r
    if op.type == "binary" and r then
        --print("FORK BINARY ",  r.value)
        self.current.r = {
            p = self.current,
            op = op,
            l = current_r,
            r = r
        }
        if self.current.r.l.op then
            self.current.r.l.p = self.current.r
        end
        self.current = self.current.r
    elseif op.type == "unary" and not r then
        --print("FORK UNARY ", self.current.r.value)
        self.current.r = {
            p = self.current,
            op = op,
            r = current_r,
            l = nil
        }
        if current_r.op then
            current_r.p = self.current.r
        end
    else
        assert("right is nil but operator is not unary")
    end
end

--- Move pointer to up of tree (by nodes)
function ast:up()
    if self.current.p then
        self.current = self.current.p
    end
end

--- Move pointer to down of tree (by nodes)
function ast:down()
    if self.current.r and not self.current.value then
        self.current = self.current.r
    end
end

--- @return aspect.ast.node|aspect.ast.leaf
function ast:get_root()
    local node = self.current
    while node.p do
        node = node.p
    end
    return node
end

local function dump_visit(node, indent)
    local out = {}
    if node.op then -- if aspect.ast.node
        insert(out, "\n" .. indent .. "OP " .. node.op.token .. " " .. (node.op.delimiter or ""))
        if node.c then
            insert(out, indent .. "c: " .. dump_visit(node.c, indent .. "    "))
        end
        if node.l then
            insert(out, indent .. "l: " .. dump_visit(node.l, indent .. "    "))
        end
        if node.r then
            insert(out, indent .. "r: " .. dump_visit(node.r, indent .. "    "))
        end
    else -- if aspect.ast.leaf
        insert(out, node.type .. "(" .. node.value .. ")")
    end

    return concat(out, "\n")
end

--- @return string
function ast:dump()
    return dump_visit(self:get_root(), "")
end

--- @param leaf aspect.ast.leaf
--- @param typ string
--- @return aspect.ast.leaf
local function cast(leaf, typ)
    if leaf.type == typ or typ == "any" then
        return leaf.value
    elseif typ == "number" then
        return "__.n(" .. leaf.value .. ")"
    elseif typ == "string" then
        return "__.s(" .. leaf.value .. ")"
    elseif typ == "boolean" then
        return "__.b(" .. leaf.value .. ")"
    elseif typ == "boolean|any" then
        if leaf.type == "boolean" then
            return leaf.value
        else
            return "__.b2(" .. leaf.value .. ")"
        end
    else
        return leaf.value
    end
end

--- @param node aspect.ast.node
--- @return aspect.ast.leaf
local function pack_tree(node)
    if node.op then -- if aspect.ast.node
        local left, right, cond = node.l, node.r, node.c
        if left then
            if left.op then
                left = pack_tree(left)
            end
            left = cast(left, node.op.l)
        end
        if right then
            if right.op then
                right = pack_tree(right)
            end
            right = cast(right, node.op.r)
        end
        if cond then
            if cond.op then
                cond = pack_tree(cond)
            end
            cond = cast(cond, node.op.c)
        end
        local v = node.op.pack(left, right, cond)
        if node.op.brackets then
            v = "(" .. v .. ")"
        end
        return {
            value = v,
            type = node.op.out,
            brackets = node.op.brackets
        }
    else -- is leaf
        return node
    end
end

--- @param node aspect.ast.node
--- @param callback fun
local function visit(node, callback)
    if node.op then -- if aspect.ast.node
        local left, right, cond = node.l, node.r, node.c
        if left and left.op then
            left = visit(left, callback)
        end
        if right and right.op then
            right = visit(right, callback)
        end
        if cond and cond.op then
            cond = visit(cond, callback)
        end
        return {
            value = callback(node.op, left, right, cond),
            type = node.op.out
        }
    else -- is leaf
        return node
    end

end

--- @param callback nil|fun(left:any, right:any, cond:any)
function ast:pack(callback)
    if callback then
        return visit(self:get_root(), callback)
    else
        return pack_tree(self:get_root())
    end
end

return ast