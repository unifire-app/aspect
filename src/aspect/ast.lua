local insert = table.insert
local concat = table.concat
local setmetatable = setmetatable
local ipairs = ipairs
local require = require
local type = type
local json_encode = require("cjson.safe").encode
local utils = require("aspect.utils")
local cast = utils.cast_lua
local var_dump = utils.var_dump

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
--- @field nodes number
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
        nodes = 0
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
                value = "(" .. compiler:parse_value(tok, info) .. ")",
                type = info.type,
                bracket = true,
                raw = info.raw
            }
        else
            leaf = {
                value = compiler:parse_value(tok, info),
                type = info.type,
                bracket = false,
                raw = info.raw
            }
        end
        if unary_op then
            self.current = {
                op = unary_op,
                l = nil,
                r = leaf
            }
            self.nodes = 2
        else
            self.current = leaf
            self.nodes = 1
        end
    end
    while tok:is_valid() do
        local token, cond, cond_type = tok:get_token(), nil, nil
        local op, op_unary, info = ops[token], nil, {}

        if op then -- binary or ternary operator
            if op.parse then
                cond, cond_type = op.parse(compiler, tok)
                if cond_type then
                    cond = {
                        value = cond,
                        type = cond_type
                    }
                end
            else
                tok:next()
            end
            if ops_unary[tok:get_token()] then -- has unary operator ('-' or 'not')
                op_unary = ops_unary[tok:get_token()]
                tok:next()
            end

            local leaf
            if tok:is("(") then
                leaf = {
                    value = "(" .. compiler:parse_value(tok, info) .. ")",
                    type = info.type,
                    bracket = true,
                    raw = info.raw
                }
            else
                leaf = {
                    value = compiler:parse_value(tok, info),
                    type = info.type,
                    bracket = false,
                    raw = info.raw
                }
            end
            self.nodes = self.nodes + 1
            if self.current.value then -- first element of the tree
                self:insert(op, leaf, cond)
            elseif self.current.op.order <= op.order then
                while self.current.p and self.current.op.order < op.order do
                    self:up()
                end
                self:insert(op, leaf, cond)
            else -- self.current.op.order > op.order
                while self.current.r.op and self.current.op.order > op.order do -- just in case
                    self:down()
                end
                self:fork(op, leaf, cond)
            end
            if op_unary then
                self:fork(op_unary, nil)
            end
        elseif ops_unary[token] then -- some unary operators are specific (e.g. 'is')
            op_unary = ops_unary[token]
            if op_unary.parse then
                cond, cond_type = op_unary.parse(compiler, tok)
                if cond then
                    cond = {
                        value = cond,
                        type = cond_type or "expr"
                    }
                end
            end
            if self.current.value then -- first element of the tree
                self:fork(op_unary, nil, cond)
            elseif self.current.op.order <= op_unary.order then
                while self.current.p and self.current.op.order < op_unary.order do
                    self:up()
                end
                self:fork(op_unary, nil, cond)
            else -- self.current.op.order > op_unary.order
                while self.current.r.op and self.current.op.order > op_unary.order do -- just in case
                    self:down()
                end
                self:fork(op_unary, nil, cond)
            end
            self.nodes = self.nodes + 1
        else
            break
        end
    end
    return self
end

--- Insert new node in the current branch
--- @param op aspect.ast.op
--- @param r aspect.ast.leaf
function ast:insert(op, r, cond)
    --print("INSERT " .. op.token)
    local parent = self.current.p
    self.current = {
        p = parent,
        op = op,
        l = self.current,
        r = r,
        c = cond
    }
    if cond and cond.op then
        cond.p = self.current
    end
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
function ast:fork(op, r, cond)
    local current_r = self.current.r
    if op.type == "binary" and r then
        self.current.r = {
            p = self.current,
            op = op,
            l = current_r,
            r = r,
            c = cond
        }
        if self.current.r.l.op then
            self.current.r.l.p = self.current.r
        end
        self.current = self.current.r
    elseif op.type == "unary" and not r then
        if cond then -- unary with cond - test operator
            self.current = {
                p = self.current.p,
                op = op,
                l = nil,
                r = self.current,
                c = cond
            }
            if self.current.r.op then
                self.current.r.p = self.current
            end
        else
            self.current.r = {
                p = self.current,
                op = op,
                l = nil,
                r = current_r,
                c = cond
            }
            if current_r.op then
                current_r.p = self.current.r
            end
        end
    else
        assert(false, "right is nil but operator is not unary")
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

--- @param node aspect.ast.node|aspect.ast.leaf
--- @param indent string
local function dump_visit(node, indent)
    local out = {}
    if node.op then -- if aspect.ast.node
        insert(out, "\n" .. indent .. "OP " .. node.op.token .. " " .. (node.op.delimiter or "") .. " (order " .. node.op.order .. " )")
        if node.c then
            insert(out, indent .. "c: " .. dump_visit(node.c, indent .. "    "))
        end
        if node.l then
            insert(out, indent .. "l: " .. dump_visit(node.l, indent .. "    "))
        end
        if node.r then
            insert(out, indent .. "r: " .. dump_visit(node.r, indent .. "    "))
        end
    elseif type(node.value) == "table" then
        insert(out, node.type .. "(" .. json_encode(node.value) .. ")")
    else
        insert(out, node.type .. "(" .. node.value .. ")")
    end

    return concat(out, "\n")
end

--- @return string
function ast:dump()
    return dump_visit(self:get_root(), "")
end


--- @param node aspect.ast.node
--- @return aspect.ast.leaf
local function pack_node(node)
    if node.op then -- if aspect.ast.node
        local left, right, cond = node.l, node.r, node.c
        if left then
            if left.op then
                left = pack_node(left)
            end
            left = cast(left.value, left.type, node.op.l)
        end
        if right then
            if right.op then
                right = pack_node(right)
            end
            right = cast(right.value, right.type, node.op.r)
        end
        if cond then
            if cond.op then
                cond = pack_node(cond)
            end
            cond = cast(cond.value, cond.type, node.op.c)
        end
        --var_dump(node)
        local v = node.op.pack(left, right, cond)
        if node.op.brackets then
            v = "(" .. v .. ")"
        end
        return {
            value = v,
            type = node.op.out,
            brackets = node.op.brackets,
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
            type = node.op.out,
        }
    else -- is leaf
        return node
    end

end

--- @param callback nil|fun(left:any, right:any, cond:any)
function ast:pack(callback)
    if callback then
        return visit(self:get_root(), callback)
    elseif self.nodes == 1 then --
        return self.current
    else
        return pack_node(self:get_root())
    end
end

return ast