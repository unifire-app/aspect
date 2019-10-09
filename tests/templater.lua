local lu = require('luaunit')
local aspect = require("aspect.template")
local tokenizer = require("aspect.tokenizer")
local compiler = require("aspect.compiler")
local dump = require("pl.pretty").dump
local tablex = require("pl.tablex")
local strip = require("pl.stringx").strip

TestTemplate = {
    templates = {}
}
TestTemplate.vars = {
    integer_0 = 0,
    integer_1 = 1,
    integer_2 = 2,
    integer_3 = 3,

    float_1 = 1.1,
    float_2 = 1e5,

    nil_value = nil,

    true_value = true,
    false_value = false,

    string_empty = "",
    string_1 = [[string value]],

    list_empty = {},
    list_1 = {"item1", "item2", "item3"},

    table_1 = {
        integer_value = 7,
        float_value = 2.1,
        string_value = "is table value",
    }
}
TestTemplate.vars.table_inf = TestTemplate.vars
TestTemplate.templates["tpl_00"] = {
    [[{{ integer_1 }} and {{ integer_2 }} and {{ "string" }} and {{ 17 }}]],
    "1 and 2 and string and 17"
}
TestTemplate.templates["tpl_01"] = {
    [[
        {% if integer_1 and float_1 and true_value and string_1 and list_1 and table_1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
TestTemplate.templates["tpl_02"] = {
    [[
        {% if 0 + integer_1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
TestTemplate.templates["tpl_03"] = {
    [[
        {% if string_1 != "random" %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
TestTemplate.templates["tpl_10"] = {
    [[
        {% if integer_0 or nil_value or false_value or string_empty or list_empty %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "failed"
}
TestTemplate.templates["tpl_11"] = {
    [[
        {% if integer_1 - 1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "failed"
}
TestTemplate.templates["tpl_20"] = {
    [[
        {% for v in list_1 %}
            {{ v }}
        {% endfor %}
    ]],
    "item1 item2 item3"
}
TestTemplate.templates["tpl_21"] = {
    [[
        {% for k, v in list_1 if v != "item2" %}
            {{ k }}: {{ v }}
        {% endfor %}
    ]],
    "1: item1 3: item3"
}
TestTemplate.templates["tpl_30"] = {
    [[{{ table_1.integer_value }} and {{ table_1.float_value }} and {{ table_1.string_value }}]],
    "7 and 2.1 and is table value"
}

TestTemplate.templates["tpl_40"] = {
    [[
    {% set var_1 = 1 %}
    {% set var_2 = "string1." ~ "string2." %}
    {% set var_3 = table_1.string_value %}
    {{ var_1 }} and {{ var_2 }} and {{ var_3 }}
    ]],

    "1 and string1.string2. and is table value"
}
TestTemplate.templates["tpl_41"] = {
    [[
    {% set var_1 %}
        content: {{ string_1 }}
        {% if integer_1 %}
            integer_1
        {% endif %}
    {% endset %}
    {{ var_1 }}
    ]],
    "content: string value integer_1"
}
TestTemplate.templates["tpl_41"] = {
    [[
    {% set var_1 %}
        {% set var_2 %}
            variable 2
        {% endset %}
        var_2: {{ var_2 }}
    {% endset %}
    {{ var_1 }} and {{ var_2 }}
    ]],
    "var_2: variable 2 and"
}
TestTemplate.templates["tpl_50"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_00' %}
    ]],
    "42 and 2 and string and 17"
}
TestTemplate.templates["tpl_51"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_00' only %}
    ]],
    "and and string and 17"
}
TestTemplate.templates["tpl_52"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_00' only with context %}
    ]],
    "1 and 2 and string and 17"
}
TestTemplate.templates["tpl_53"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_00' only with vars %}
    ]],
    "42 and and string and 17"
}
TestTemplate.templates["tpl_54"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_00' only with vars with context with {integer_1: 4} %}
    ]],
    "4 and 2 and string and 17"
}
TestTemplate.templates["tpl_55"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_none' %}
    ]],
    nil,
    "Template(s) not found. Trying tpl_none"
}
TestTemplate.templates["tpl_56"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_none' ignore missing %}
    ]],
    ""
}
TestTemplate.templates["tpl_57"] = {
    [[
    {% set integer_1 = 42 %}
    {% include ['tpl_none', 'tpl_none2'] %}
    ]],
    nil,
    "Template(s) not found. Trying tpl_none, tpl_none2"
}
TestTemplate.templates["tpl_58"] = {
    [[
    {% set integer_1 = 42 %}
    {% include ['tpl_none', 'tpl_none2'] ignore missing %}
    ]],
    ""
}
--TestTemplate.templates["hello"] = [[
--{% if user and not user.deleted %}
--    hello, {{ user.name }}!
--{% endif %}
--
--{% for id, u in user.list %}
--    * {{ id }}: {{ u.name }}
--{% endfor %}
--
--{% block content scoped %}
--    this is block
--    {{ content }}
--{% endblock %}
--
--{% macro input(name, value, type = "text", size = 20) %}
--    <input type="{{ type }}" name="{{ name }}" value="{{ value }}" size="{{ size }}" />
--{% endmacro %}
--]]

function TestTemplate:run_parser(tests, callback)
    for i,t in pairs(tests) do
        local tpl = compiler.new()
        local tok = tokenizer.new(t[1])
        local ok, lua = pcall(tpl[callback], tpl, tok)
        --local ok, lua = pcall(tpl.parse_value, tpl, tok)
        if not ok then
            if type(lua) == "table" then
                lu.fail(tostring(lua))
            else
                lu.fail(lua .. "; compile template " .. t[1])
            end
        end
        lu.assertIs(tostring(lua), t[2], "compile template " .. t[1])
    end
end

function TestTemplate:test_01_tokenize()
    local tok = tokenizer.new("for i,j in vers|select('this', \"oh\") %}")
    lu.assertIs(tok:get_token(), "for")
    lu.assertIsTrue(tok:is_word())

    tok:next() -- i
    lu.assertIs(tok:get_token(), "i")
    lu.assertIsTrue(tok:is_word())

    tok:next() -- ,
    lu.assertIs(tok:get_token(), ",")
    lu.assertIs(tok:get_token_type(), ",")

    tok:next() -- j
    tok:next() -- in

    lu.assertIs(tok:get_token(), "in")
    lu.assertIsTrue(tok:is_word())

    tok:next() -- vers
    tok:next() -- |
    lu.assertIs(tok:get_token(), "|")
    lu.assertIs(tok:get_token_type(), "|")

    lu.assertIsTrue(tok:is_valid())

    tok:next() -- select
    tok:next() -- (
    tok:next() -- 'this'
    lu.assertIs(tok:get_token(), "'this'")
    lu.assertIsTrue(tok:is_string())

    tok:next() -- ,
    tok:next() -- "oh"
    lu.assertIs(tok:get_token(), '"oh"')
    lu.assertIsTrue(tok:is_string())

    tok:next() -- )

    lu.assertIsTrue(tok:is_valid())

    tok:next() -- %}

    lu.assertIsFalse(tok:is_valid())
    lu.assertIs(tok:get_token(), "%}")
    lu.assertIs(tok:get_token_type(), "stop")

    tok:next() -- %}

    lu.assertIsFalse(tok:is_valid())
    lu.assertIs(tok:get_token(), "%}")
end

function TestTemplate:provider_values()
    return {
        {'one', 'one'},
        {'one', 'one'},
        {'one.two.three', 'one["two"]["three"]'},
        {'one["two"].three["four"]["five"]', 'one["two"]["three"]["four"]["five"]'},
        {'one.two|dummy', [[_self.f['dummy'](one["two"])]]},
        {'one.two|dummy(1, "three")', [[_self.f['dummy'](one["two"], 1, "three")]]},
        {'one.two|dummy1|dummy2(2, "two")', [[_self.f['dummy2'](_self.f['dummy1'](one["two"]), 2, "two")]]},

        {'1', "1"},
        {'1|dummy', [[_self.f['dummy'](1)]]},

        {'"one"', '"one"'},
        {'"one"|dummy', [[_self.f['dummy']("one")]]},
        {"'one'", "'one'"},

        {"[]", "{}"},
        {'[1, "one", three.four]', '{1, "one", three["four"]}'},

        {"{}", "{}"},
        {[[{"one": 1, 2: "two", three: four|dummy}]], [[{["one"] = 1, [2] = "two", ["three"] = _self.f['dummy'](four)}]]}
    }
end

function TestTemplate:provider_expression()
    local exprs = {}
    local ops = {
        {"+", "+"},
        {"-", "-"},
        {"/", "/"},
        {"*", "*"},
        {"%", "%"},
        {"**", "^"},
    }
    local comp_ops = {
        {"==", "=="},
        {"!=", "~="},
        {">=", ">="},
        {"<=", "<="},
        {"<", "<"},
        {">", ">"},
    }
    local logic_ops = {
        {"and", "and"},
        {"and", "and"},
        {"or", "or"},
        {"or", "or"},
        {"and not", "and not"},
        {"or not", "or not"},
    }

    local one_1, two_1, three_1, four_1 = "one", "two", "three", "four"
    local one_2, two_2, three_2, four_2 = 'one', 'two', 'three', 'four'
    for i=1,6 do
        table.insert(exprs, {
            one_1 .. " " .. ops[i][1] .. " " .. two_1 .. " " .. comp_ops[i][1] .. " " .. three_1 .. " " .. logic_ops[i][1] .. " " .. four_1,
            one_2 .. " " .. ops[i][2] .. " " .. two_2 .. " " .. comp_ops[i][2] .. " " .. three_2 .. " " .. logic_ops[i][2] .. " " .. four_2,
        })
        table.insert(exprs, {
            "(" .. one_1 .. " " .. ops[i][1] .. " " .. two_1 .. ") " .. comp_ops[i][1] .. " " .. three_1 .. " " .. logic_ops[i][1] .. " " .. four_1,
            "(" .. one_2 .. " " .. ops[i][2] .. " " .. two_2 .. ") " .. comp_ops[i][2] .. " " .. three_2 .. " " .. logic_ops[i][2] .. " " .. four_2,
        })
    end
    return exprs
end

function TestTemplate:_test_03_expression()
    self:run_parser(self:provider_values(), 'parse_expresion')
    self:run_parser(self:provider_expression(), 'parse_expresion')
end

function TestTemplate:test_template_body()
    local template = aspect.new()
    template.loader = function(tpl, name)
        if TestTemplate.templates[name] then
            return TestTemplate.templates[name][1]
        else
            return nil
        end
    end
    for k, v in tablex.sort(TestTemplate.templates) do
        local result, err = template:fetch(k, TestTemplate.vars)
        if result then
            result = string.gsub(result, "%s+", " ")
            lu.assertIs(strip(result), v[2], "Test template ".. k ..":\n" .. v[1])
        elseif not v[2] and v[3] then
            lu.assertIs(err.message, v[3])
        else
            lu.fail(tostring(err) .. "\n\nTest template ".. k ..":\n" .. v[1])
        end
    end
            --.render:fetch({
        --user = {
        --    name = "Ivan",
        --    email = "a.cobest@gmail.com"
        --}
    --})
end


local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
os.exit( runner:runSuite() )