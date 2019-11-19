package.path = "./src/?.lua;" .. package.path
local aspect = require("aspect.template")
local tokenizer = require("aspect.tokenizer")
local astree = require("aspect.ast")
local compiler = require("aspect.compiler")
local filters = require("aspect.filters")
local err = require("aspect.err")
local dump = require("pl.pretty").dump
local tablex = require("pl.tablex")
local strip = require("pl.stringx").strip
local json_encode = require("cjson.safe").encode
local assert = require("luassert")
local cjson = require("cjson.safe")

require('busted.runner')()


local vars = {
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
    string_html = [[<b>Hello</b>]],

    date_1 = "2019-11-11 09:55:30",
    date_2 = "2019-11-11 09:56:30",

    list_empty = {},
    list_1 = {"item1", "item2", "item3"},

    table_1 = {
        float_value = 2.1,
        integer_value = 7,
        string_value = "is table value",
    }
}
vars.table_inf = vars

local ast_expr = {
    { -- binary operators
        expr = "1 + 2 + 3 * 4 * 5 - 6 or 7 and 8 ** 9 or 10",
        ast = "(((((1 [+] 2) [+] ((3 [*] 4) [*] 5)) [-] 6) [or] (7 [and] (8 [**] 9))) [or] 10)"
    },
    { -- unary operators
        expr = "1 + -2 ** 3 * 4",
        ast = "((1 [+] ([-] (2 [**] 3))) [*] 4)"
    },
    { -- ternary operators
        expr = "1 ? 2 ? 3 ?: 4 : 5 : 6",
        ast = "(1 [?] (2 [?] (3 [?:] 4) [:] 5) [:] 6)"
    },
    { -- unary operators at first
        expr = "- 1 * 2 + 3",
        ast = "((([-] 1) [*] 2) [+] 3)"
    },
    { -- brackets and unary operators before brackets
        expr = "(1 + 2) + - (3 * 4)",
        ast = "((1 + 2) [+] ([-] (3 * 4)))"
    },
    { -- brackets and unary operators before brackets
        expr = "1 ** 2 is odd and 3",
        ast = '(((1 [**] 2) [is {"name":"odd"}]) [and] 3)'
    }
}

local templates = {}

templates["basic_00"] = {
    [[{{ integer_1 }} and {{ integer_2 }} and {{ "string" }} and {{ 17 }}]],
    "1 and 2 and string and 17"
}
templates["basic_01"] = {
    [[{{ 1 + 2 + 3 * 4 * 5 - 6 ~ "|" ~ 7 ~ "|" ~ (8 ** 9)|round ~ "|" ~ 10 }}]],
    "57|7|134217728|10"
}

templates["basic_02"] = {
    [[{{ integer_0 ? integer_1 : integer_2 }}]],
    "2"
}
templates["basic_03"] = {
    [[{{ integer_0 ?: integer_1}}]],
    "1"
}
templates["basic_04"] = {
    [[{{ integer_3 ? integer_1 : integer_2 }}]],
    "1"
}
templates["basic_05"] = {
    [[{{ integer_3 ?: integer_2 }}]],
    "3"
}
templates["basic_06"] = {
    [[{{ table_1.integer_value }} and {{ table_1.float_value }} and {{ table_1.string_value }}]],
    "7 and 2.1 and is table value"
}

templates["basic_07"] = {
    [[{{ integer_3 * + }}]],
    nil,
    "unexpected token '+', expecting any value"
}

templates["if_01"] = {
    [[
        {% if integer_1 and float_1 and true_value and string_1 and list_1 and table_1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
templates["if_02"] = {
    [[
        {% if 0 + integer_1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
templates["if_03"] = {
    [[
        {% if string_1 != "random" %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "passed"
}
templates["if_04"] = {
    [[
        {% if integer_0 or nil_value or false_value or string_empty or list_empty %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "failed"
}
templates["if_05"] = {
    [[
        {% if integer_1 - 1 %}
            passed
        {% else %}
            failed
        {% endif %}
    ]],
    "failed"
}
templates["for_00"] = {
    [[
        {% for v in list_1 %}
            {{ v }}
        {% endfor %}
    ]],
    "item1 item2 item3"
}
templates["for_01"] = {
    [[
        {% for k, v in list_1 if v != "item2" %}
            {{ k }}: {{ v }}
        {% endfor %}
    ]],
    "1: item1 3: item3"
}
templates["for_02"] = {
    [[
        {% for k, v in list_1 %}
            {{ loop.index }}: {{ v }} {% if not loop.last %}|{% endif %}
        {% endfor %}
    ]],
    "1: item1 | 2: item2 | 3: item3"
}


templates["set_00"] = {
    [[
    {% set var_1 = 1 %}
    {% set var_2 = "string1." ~ "string2." %}
    {% set var_3 = table_1.string_value %}
    {{ var_1 }} and {{ var_2 }} and {{ var_3 }}
    ]],

    "1 and string1.string2. and is table value"
}
templates["set_01"] = {
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
templates["set_02"] = {
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
templates["include_00"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'basic_00' %}
    ]],
    "42 and 2 and string and 17"
}
templates["include_01"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'basic_00' only %}
    ]],
    "and and string and 17"
}
templates["include_02"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'basic_00' only with context %}
    ]],
    "1 and 2 and string and 17"
}
templates["include_03"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'basic_00' only with vars %}
    ]],
    "42 and and string and 17"
}
templates["include_04"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'basic_00' only with vars with context with {integer_1: 4} %}
    ]],
    "4 and 2 and string and 17"
}
templates["include_05"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_none' %}
    ]],
    nil,
    "Template(s) not found. Trying tpl_none"
}
templates["include_06"] = {
    [[
    {% set integer_1 = 42 %}
    {% include 'tpl_none' ignore missing %}
    ]],
    ""
}
templates["include_07"] = {
    [[
    {% set integer_1 = 42 %}
    {% include ['tpl_none', 'tpl_none2'] %}
    ]],
    nil,
    "Template(s) not found. Trying tpl_none, tpl_none2"
}
templates["include_08"] = {
    [[
    {% set integer_1 = 42 %}
    {% include ['tpl_none', 'tpl_none2'] ignore missing %}
    ]],
    ""
}
templates["extends_01"] = {
    [[
    {% block one %}
        block one
    {% endblock %}
    [and]
    {% block two %}
        block two
    {% endblock two %}
    ]],
    "block one [and] block two"
}
templates["extends_02"] = {
    [[
    {% extends "extends_01" %}
    {% block one %}
        block one from extends_02
    {% endblock %}
    invalid content
    ]],
    "block one from extends_02 [and] block two"
}
templates["extends_03"] = {
    [[
    {% block one %}
        block one from extends_03
    {% endblock %}
    {% if block("one") %}
        has block one
    {% endif %}
    ]],
    "block one from extends_03 has block one"
}

templates["extends_03"] = {
    [[
    {% set var = 1 %}
    {% block one %}
        var: {{ var }}
    {% endblock %}
    {% set var = 2 %}
    {{ block("one") }}
    ]],
    "var: 1 var: 2"
}

templates["extends_04"] = {
    [[
    {% extends "extends_01" %}
    {% block one %}
        block one from extends_02 [and] {{ parent() }}
    {% endblock %}
    invalid content
    ]],
    "block one from extends_02 [and] block one [and] block two"
}

templates["range_01"] = {
    [[
    {% for k,v in range(1,3) %}
        {{ k }}: {{ v }},
    {% endfor %}
    ]],
    "1: 1, 2: 2, 3: 3,"
}
templates["range_02"] = {
    [[
    {% for k,v in range(step=-2, from=5, to=0) %}
        {{ k }}: {{ v }},
    {% endfor %}
    ]],
    "1: 5, 2: 3, 3: 1,"
}

templates["macro_01"] = {
    [[
    {% macro key_value(key, value = "none") %}
        [{{ key }}: {{ value }}]
    {% endmacro %}

    {{ _self.key_value("one") }}
    {{ _self.key_value("two", "value1") }}
    {{ _self.key_value(value = "value2") }}
    {{ _self.key_value(value = "value3", key = "three") }}
    ]],
    "[one: none] [two: value1] [: value2] [three: value3]"
}
templates["macro_02"] = {
    [[
    {% import "macro_01" as sample %}

    {{ sample.key_value("one") }}
    {{ sample.key_value("two", "value1") }}
    {{ sample.key_value(value = "value2") }}
    {{ sample.key_value(value = "value3", key = "three") }}
    ]],
    "[one: none] [two: value1] [: value2] [three: value3]"
}
templates["macro_03"] = {
    [[
    {% from "macro_01" import key_value %}

    {{ key_value("one") }}
    {{ key_value("two", "value1") }}
    {{ key_value(value = "value2") }}
    {{ key_value(value = "value3", key = "three") }}
    ]],
    "[one: none] [two: value1] [: value2] [three: value3]"
}

templates["macro_04"] = {
    [[
    {% from "macro_01" import key_value as woo, key_value as foo %}

    {{ woo("one") }}
    {{ woo("two", "value1") }}
    {{ woo(value = "value2") }}
    {{ woo(value = "value3", key = "three") }}
    ]],
    "[one: none] [two: value1] [: value2] [three: value3]"
}

templates["is_01"] = {
    [[
    {% if integer_1 is defined or integer_0 %}
    defined
    {% endif %}
    ]],
    "defined"
}

templates["is_01"] = {
    [[
    {{ integer_2 ** integer_3 is even ~ " is" }}
    ]],
    "true is"
}

templates["is_01"] = {
    [[
    {{ integer_2 ** integer_3 is not even ~ " is" }}
    ]],
    "is"
}

templates["in_01"] = {
    [[
    has: {{ integer_2 in [1, 3] }}
    ]],
    "has:"
}

templates["in_02"] = {
    [[
    has: {{ integer_2 in [1, 2, 3] }}
    ]],
    "has: true"
}

templates["in_02"] = {
    [[
    has: {{ integer_2 not in [1, 2, 3] }}
    ]],
    "has:"
}

templates["date_01"] = {
    [[
    {% if date("2019-11-11 09:56:30") > date("2019-11-11 09:55:30") %}
        valid
    {% else %}
        in valid
    {% endif %}
    [and]
    {% if date("2019-11-11 09:56:30") < date("2019-11-11 09:55:30") %}
        valid
    {% else %}
        not valid
    {% endif %}
    [and]
    {% if date("2019-11-11 09:55:30") == date("2019-11-11 09:56:30") %}
        valid
    {% else %}
        not valid
    {% endif %}
    [and]
    {% if date("2019-11-11 09:55:30") != date("2019-11-11 09:56:30") %}
        valid
    {% else %}
        in valid
    {% endif %}
    [and]
    {% if date("2019-11-11 09:56:30") == date("2019-11-11 09:56:30") %}
        valid
    {% else %}
        in valid
    {% endif %}
    ]],
    "valid [and] not valid [and] not valid [and] valid [and] valid"
}

templates["date_02"] = {
    [[
        {% if date_1|date_modify({"minutes": 1}) == date(date_2) %}
            equals
        {% endif %}
    ]],
    "equals"
}


templates["autoescape_00"] = {
    "<pre>{{ string_html }}</pre>",
    "<pre>&lt;b&gt;Hello&lt;&#47;b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_01"] = {
    "<pre>{{ string_html|raw }} [and] {{ string_html }}</pre>",
    "<pre><b>Hello</b> [and] &lt;b&gt;Hello&lt;&#47;b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_02"] = {
    "<pre>{{ 'yeah, ' ~ string_html|raw }}</pre>",
    "<pre>yeah, &lt;b&gt;Hello&lt;&#47;b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_03"] = {
    "{% autoescape %}<pre>{{ string_html }}</pre>{% endautoescape %}",
    "<pre>&lt;b&gt;Hello&lt;&#47;b&gt;</pre>",
}

templates["autoescape_04"] = {
    "{% autoescape false%}<pre>{{ string_html }}</pre>{% endautoescape %}",
    "<pre><b>Hello</b></pre>",
}

templates["autoescape_05"] = {
    "{% autoescape false%}<pre>{{ string_html }}</pre>{% endautoescape %}",
    "<pre><b>Hello</b></pre>",
    nil,
    { autoescape = true }
}


templates["filter:first_last_01"] = {
    "{{ list_1|first }} | {{ list_1|last }} || "
        .. "{{ range(1, 5, 2)|first }} | {{ range(1, 5, 2)|last }} || "
        .. "{{ table_1|first }} | {{ table_1|last }}",
    -- table is dict and no has order, just checks what all ok
    "item1 | item3 || 1 | 5 || " ..  filters.first(vars.table_1) .. " | " .. filters.last(vars.table_1)
}

templates["filter:join_01"] = {
    "{{ list_1|join(',') }} | {{ range(1, 5, 2)|join(',') }} | {{ table_1|join(',') }}",
    -- table is dict and no has order, just checks what all ok
    "item1,item2,item3 | 1,3,5 | " .. filters.join(vars.table_1, ",")
}

templates["filter:keys_01"] = {
    "{{ list_1|keys|join(',') }} | {{ range(1, 5, 2)|keys|join(',') }} | {{ table_1|keys|join(',') }}",
    -- table is dict and no has order, just checks what all ok
    "1,2,3 | 1,2,3 | " .. filters.join(filters.keys(vars.table_1), ",")
}

templates["filter:length_01"] = {
    "{{ list_1|length }} | {{ range(1, 5, 2)|length }} | {{ table_1|length }} | {{ string_1|length }} | {{ empty_string|length }}",
    "3 | 3 | 3 | 12 | 0"
}

templates["filter:escape_01"] = {
    "{{ string_html|e }}",
    "&lt;b&gt;Hello&lt;&#47;b&gt;"
}

templates["filter:escape_02"] = {
    "{{ string_html|e('js') }}",
    cjson.encode(vars.string_html)
}

templates["filter:escape_03"] = {
    "{{ string_1|e('url') }}",
    "string+value"
}

templates["filter:default_01"] = {
    "{{ nil_value|default('empty') }} [and] {{ nil_value|default('empty', true) }}",
    "empty [and] empty"
}

templates["filter:default_02"] = {
    "{{ integer_0|default('empty') }} [and] {{ integer_0|default('empty', true) }}",
    "0 [and] empty"
}


templates["filter:trim_01"] = {
    ".{{ ' spaced '|trim(' ', 'left') }}.{{ ' spaced '|trim(' ', 'right') }}.{{ ' spaced '|trim }}",
    ".spaced . spaced.spaced"
}


templates["function:dump_01"] = {
    "{{ dump(list_1) }}",
    "function:dump_01:1: { (string) item1 (string) item2 (string) item3 } Stack: begin function:dump_01:1"
}




describe("Testing compiler.", function()
    it("Checks tokenizer", function()
        local str = "for i,j in vers|select('this', \"oh\") %}"
        local tok = tokenizer.new(str)
        assert.are.equals(tok:get_token(), "for")
        assert.is.True(tok:is_word())

        tok:next() -- i
        assert.are.equals(tok:get_token(), "i")
        tok:require("i")
        tok:require_type("word")
        assert.is.True(tok:is_word())
        assert.is.True(tok:is_seq({"word", ",", "word", "word", "word", "|", "word", "(", "string"}))

        tok:next() -- ,
        assert.are.equals(tok:get_token(), ",")
        assert.are.equals(tok:get_token_type(), ",")

        tok:next() -- j
        tok:next() -- in

        assert.are.equals(tok:get_token(), "in")
        assert.is.True(tok:is_word())

        tok:next() -- vers
        tok:next() -- |
        assert.are.equals(tok:get_token(), "|")
        assert.are.equals(tok:get_token_type(), "|")

        assert.is.True(tok:is_valid())

        tok:next() -- select
        tok:next() -- (
        tok:next() -- 'this'
        assert.are.equals(tok:get_token(), "'this'")
        assert.is.True(tok:is_string())

        tok:next() -- ,
        tok:next() -- "oh"
        assert.are.equals(tok:get_token(), '"oh"')
        assert.is.True(tok:is_string())

        tok:next() -- )

        assert.is.True(tok:is_valid())

        tok:next() -- %}

        assert.is.False(tok:is_valid())
        assert.are.equals(tok:get_token(), nil)
        assert.are.equals(tok:get_token_type(), nil)

        tok:next() -- %}

        assert.is.False(tok:is_valid())
        assert.are.equals(tok:get_token(), nil)

        assert.are.equals(tok:get_path_as_string() .. "%}", str)
    end)



    for _, e in ipairs(ast_expr) do
        it("Checks AST: " .. e.expr, function ()
            local template = aspect.new()
            local ast = astree.new()
            local ok, f = pcall(ast.parse, ast, template:get_compiler("runtime"), tokenizer.new(e.expr))
            if not ok then
                error(tostring(err.new(f)))
            end
            local result = ast:pack(function (op, left, right, cond)
                if op.token == "?" then
                    return "(" .. left.value .. " [?] " .. cond.value .. " [:] "  .. right.value .. ")"
                elseif op.type == "binary" then
                    return "(" .. left.value .. " [" .. op.token .. "] " .. right.value .. ")"
                elseif cond then -- unary with cond
                    return "(" .. right.value .. " [" .. op.token .. " " .. json_encode(cond.value) .. "])"
                else -- unary without cond
                    return "([" .. op.token .. "] " .. right.value .. ")"
                end
            end)
            assert.is.equals(result.value, e.ast, "Pack of AST " .. e.expr .. ":\n" .. ast:dump())

        end)
    end
end)

describe("Testing template.", function ()
    for k, v in tablex.sort(templates) do
        local template = aspect.new(v[4] or {})
        template.loader = function(tpl, name)
            if templates[name] then
                return templates[name][1]
            else
                return nil
            end
        end
        local compiled = {}
        template.luacode_save = function (tpl, name, code)
            compiled[#compiled + 1] = "\n==== Compiled template " .. name .. ":\n" .. code
        end
        it("Run template " .. k, function ()
            compiled = {}
            local result, err = template:render(k, vars)
            if result then
                result = string.gsub(result, "%s+", " ")
                assert.is.equals(v[2], strip(result), "Test template ".. k ..":\n" .. v[1] .. "\nCompiled template:\n" .. table.concat(compiled))
            elseif not v[2] and v[3] then
                assert.is.equals(err.message, v[3])
            else
                error(tostring(err) .. "\n\nTest template ".. k ..":\n" .. v[1] .. "\nCompiled template:\n" .. table.concat(compiled))
            end
        end)
    end
end)