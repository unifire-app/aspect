package.path = "./src/?.lua;" .. package.path
local config = require("aspect.config")
local aspect = require("aspect.template")
local tokenizer = require("aspect.tokenizer")
local astree = require("aspect.ast")
local compiler = require("aspect.compiler")
local filters = require("aspect.filters").fn
local funcs = require("aspect.funcs")
local var_dump = require("aspect.utils").var_dump
local dump_table = require("aspect.utils").dump_table
local numerate_lines = require("aspect.utils").numerate_lines
local batch = require("aspect.utils.batch")
local date = require("aspect.date")
local err = require("aspect.error")
local strip = require("aspect.utils").strip
local json_encode = require("cjson.safe").encode
local assert = require("luassert")
local cjson = require("cjson.safe")
local tsort,append,remove = table.sort,table.insert,table.remove

local has_utf = config.utf8.match

require('busted.runner')()

local function spaceless(v)
    v = string.gsub(v, "%s+", " ")
    return strip(v)
end

--- return an iterator to a table sorted by its keys
-- @within Iterating
-- @tab t the table
-- @func f an optional comparison function (f(x,y) is true if x < y)
-- @usage for k,v in tablex.sort(t) do print(k,v) end
-- @return an iterator to traverse elements sorted by the keys
local function sort(t,f)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    tsort(keys,f)
    local i = 0
    return function()
        i = i + 1
        return keys[i], t[keys[i]]
    end
end


local large = {}
for i=1, 1000 do
    large[i] = 10 + i
end

config.date.months_locale.ru = {
    [1]  = {"Янв", "Январь"},
    [2]  = {"Фев", "Февраль"},
    [3]  = {"Мар", "Март"},
    [4]  = {"Апр", "Апрель"},
    [5]  = {"Май", "Май"},
    [6]  = {"Июн", "Июнь"},
    [7]  = {"Июл", "Июль"},
    [8]  = {"Авг", "Август"},
    [9]  = {"Сен", "Сентябрь"},
    [10] = {"Окт", "Октябрь"},
    [11] = {"Ноя", "Ноябрь"},
    [12] = {"Дек", "Декабрь"},
}
config.date.months["янв"] = 1
config.date.months["фев"] = 2
config.date.months["мар"] = 3
config.date.months["апр"] = 4
config.date.months["май"] = 5
config.date.months["июн"] = 6
config.date.months["июл"] = 7
config.date.months["авг"] = 8
config.date.months["сен"] = 9
config.date.months["окт"] = 10
config.date.months["ноя"] = 11
config.date.months["дек"] = 12

config.date.months["январь"]  = 1
config.date.months["февраль"] = 2
config.date.months["март"]    = 3
config.date.months["апрель"]  = 4
config.date.months["май"]     = 5
config.date.months["июнь"]    = 6
config.date.months["июль"]    = 7
config.date.months["август"]  = 8
config.date.months["сенябрь"] = 9
config.date.months["октябрь"] = 10
config.date.months["ноябрь"]  = 11
config.date.months["декабрь"] = 12
config.date.week_locale.ru = {
    [1] = {"Пн", "Понедельник"},
    [2] = {"Вт", "Вторник"},
    [3] = {"Ср", "Среда"},
    [4] = {"Чт", "Четверг"},
    [5] = {"Пт", "Пятница"},
    [6] = {"Сб", "Суббота"},
    [7] = {"Вс", "Воскресение"},
}

local vars = {
    integer_0 = 0,
    integer_1 = 1,
    integer_2 = 2,
    integer_3 = 3,
    integer_4 = -4,

    float_1 = 1.1,
    float_2 = 1e5,
    float_3 = 2.7,

    nil_value = nil,

    true_value = true,
    false_value = false,

    string_empty = "",
    string_1 = [[string value]],
    string_2 = [[Hello, World]],
    string_ru_2 = [[Привет, Мир]],
    string_html = [[<b>Hello</b>]],
    string_list1 = [[a,b,c]],
    string_list2 = "a \tb\n\t c",

    date_1 = "2019-11-11 09:55:30",
    date_2 = "2019-11-11 09:56:30",

    list_empty = {},
    list_1 = {"item1", "item2", "item3"},
    list_2 = { {name = "item2.1"}, {name = "item2.2"}, {name = "item2.3"} },
    list_large = large,

    table_1 = {
        float_value = 2.1,
        integer_value = 7,
        string_value = "is table value",
    },

    key_string_value = "string_value"
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
    "unexpected token '+', expecting any value [basic_07:1]"
}

templates["basic_08"] = {
    [[{{ table_1.none }} and {{ non }} and {{ table_inf.table_inf.none }}]],
    "and and"
}

templates["basic_09"] = {
    [[{{ table_1.integer_value }} and1 { not a tag } and2 {{ table_1.string_value }}]],
    "7 and1 { not a tag } and2 is table value"
}

templates["basic_10"] = {
    [[{{ table_1[key_string_value] }} and {{ table_1['float_' ~ 'value'] }} ]],
    "is table value and 2.1"
}
--
--templates["basic_10"] = {
--    [[
--    {% if table_1.integer_value %}
--        {{ table_1.integer_value }} and1 {{ wow.string_value }}
--    {% endif %}
--    ]],
--    "7 and1 dd"
--}

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
templates["comments_00"] = {
    [[
        {# comment #}
    ]],
    ""
}
templates["comments_01"] = {
    [[
        {# comment %}

         #}
    ]],
    ""
}


templates["for_00"] = {
    [[
        {% for v in list_1 %}
            {{ v }}
        {% endfor %}
    ]],
    "item1 item2 item3"
}

templates["for_02"] = {
    [[
        {% for k, v in list_1 %}
            {{ loop.index }}: {{ v }} {% if not loop.last %}|{% endif %}
        {% endfor %}
    ]],
    "1: item1 | 2: item2 | 3: item3"
}
templates["for_03"] = {
    [[
        {% for k, v in list_large %}
            {{v}}
        {% endfor %}
    ]],
    table.concat(vars.list_large, " ") .. " "
}

templates["for_10"] = {
    [[
        {% for k, v in list_1 %}
            {{ k }}: {{ v }} (prev: {{ loop.prev_item }}, next: {{ loop.next_item }}) {% if loop.has_more %}|{% endif %}
        {% endfor %}
    ]],
    "1: item1 (prev: , next: item2) | 2: item2 (prev: item1, next: item3) | 3: item3 (prev: item2, next: )"
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

templates["apply_00"] = {
    [[
    {% apply|upper %}
        val: {{ string_1 }}
    {% endapply %}
    ]],
    "VAL: STRING VALUE"
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
    "Template(s) not found. Trying tpl_none [include_05:2]"
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
    "Template(s) not found. Trying tpl_none, tpl_none2 [include_07:2]"
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

templates["extends_05"] = {
    [[
    {% use "extends_01" %}
    {% block one %}
        block one from extends_05
    {% endblock %}
    [and]
    {{ block("two") }}
    ]],
    "block one from extends_05 [and] block two"
}

templates["extends_06"] = {
    [[
    {% use "extends_01" with one as two %}
    {% block one %}
        block one from extends_05
    {% endblock %}
    [and]
    {{ block("two") }}
    ]],
    "block one from extends_05 [and] block one"
}

templates["extends_07"] = {
    [[
    {% extends true_value ? "extends_01" : "tpl_none" %}
    {% block one %}
        block one from extends_02
    {% endblock %}
    invalid content
    ]],
    "block one from extends_02 [and] block two"
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
    "<pre>&lt;b&gt;Hello&lt;/b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_01"] = {
    "<pre>{{ string_html|raw }} [and] {{ string_html }}</pre>",
    "<pre><b>Hello</b> [and] &lt;b&gt;Hello&lt;/b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_02"] = {
    "<pre>{{ 'yeah, ' ~ string_html|raw }}</pre>",
    "<pre>yeah, &lt;b&gt;Hello&lt;/b&gt;</pre>",
    nil,
    { autoescape = true }
}

templates["autoescape_03"] = {
    "{% autoescape %}<pre>{{ string_html }}</pre>{% endautoescape %}",
    "<pre>&lt;b&gt;Hello&lt;/b&gt;</pre>",
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
    "&lt;b&gt;Hello&lt;/b&gt;"
}

templates["filter:escape_02"] = {
    "{{ string_html|e('js') }}",
    cjson.encode(vars.string_html)
}

templates["filter:escape_03"] = {
    "{{ string_1|e('url') }}",
    "string+value"
}

templates["filter:escape_04"] = {
    "{{ string_html|escape }}",
    "&lt;b&gt;Hello&lt;/b&gt;"
}

templates["filter:escape_05"] = {
    [[
    {% apply|escape %}
      {{ string_html }}
    {% endapply %}
    ]],
    "&lt;b&gt;Hello&lt;/b&gt;"
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

templates["filter:abs_00"] = {
    "{{ integer_3|abs }} [and] {{ integer_4|abs }}",
    "3 [and] 4"
}

templates["filter:round_00"] = {
    "{{ float_1|round }} [and] {{ float_3|round }}",
    "1 [and] 3"
}

templates["filter:column_00"] = {
    "{{ list_2|column('name')|join(',') }}",
    "item2.1,item2.2,item2.3"
}

templates["filter:upper_lower_00"] = {
    "{{ string_2|upper }} [and] {{ string_2|lower }}",
    "HELLO, WORLD [and] hello, world"
}

templates["filter:utf.upper_utf.lower_00"] = {
    "{{ string_ru_2|utf.upper }} [and] {{ string_ru_2|utf.lower }}",
    "ПРИВЕТ, МИР [and] привет, мир"
}

templates["filter:replace_00"] = {
    "{{ string_2|replace({World: 'User', Hello: 'Hi'}) }}",
    "Hi, User"
}

templates["filter:striptags_00"] = {
    "{{ string_html|striptags }}",
    "Hello"
}

templates["filter:merge_00"] = {
    [[
    {% for k, v in table_1|merge(list_1) %}
    x,
    {% endfor %}
    ]],
    "x, x, x, x, x, x," -- keys in tables are sorted randomly.
}

templates["function:dump_01"] = {
    "{{ dump(list_1) }}",
    "Dump values: list_1: { (string) item1 (string) item2 (string) item3 } Stack: begin function:dump_01:1"
}

templates["filter:split_00"] = {
    [[
    {% for v in string_list1|split(",") %}
        {{v}}:
    {% endfor %}
    ]],
    "a: b: c:"
}
templates["filter:split_01"] = {
    [[
    {% for v in string_list1|split("") %}
        {{v}}:
    {% endfor %}
    ]],
    "a,b,c:"
}
templates["filter:split_02"] = {
    [[
    {% for k,v in string_list2|split()%}
        {{v}}:
    {% endfor %}
    ]],
    "a: b: c:"
}
templates["filter:split_03"] = {
    [[
    {% for v in string_list1|split(",", 2) %}
        {{v}}:
    {% endfor %}
    ]],
    "a: b,c:"
}

templates["filter:truncate"] = {
    [[
    {{- "hello"|utf.truncate(3, "---") -}}
    ]],
    "hel---"
}

templates["filter:utf.truncate"] = {
    [[
    {{- "привет"|utf.truncate(3, "---") -}}
    ]],
    "при---"
}
--templates["function:dump_02"] = {
--    "{{ dump(table_1) }}",
--    spaceless(funcs.fn.dump(vars.table_1))
--}
--
--templates["function:dump_03"] = {
--    "{{ dump(table_inf) }}",
--    spaceless(funcs.fn.dump(vars.table_inf))
--}

templates["tests_00"] = {
    "{% if none is defined %} defined {% endif %} [and] {% if none is not defined %} not defined {% endif %}",
    "[and] not defined"
}

templates["tests_01"] = {
    "{% if none is null %} null {% endif %} [and] {% if none is nil %} nil {% endif %} [and] {% if integer_0 is nil %} nil {% endif %}",
    "null [and] nil [and]"
}

templates["tests_02"] = {
    "{% if 4 is divisible by(2) %} divisible {% endif %} [and] {% if 5 is divisible by(2) %} divisible {% endif %}",
    "divisible [and]"
}

templates["tests_03"] = {
    "{% if integer_0 is empty %} empty {% endif %} [and] {% if integer_1 is empty %} empty {% endif %}",
    "empty [and]"
}

templates["tests_04"] = {
    "{% if 4 is odd %} odd {% endif %} [and] {% if 5 is odd %} odd {% endif %}",
    "[and] odd"
}

templates["tests_05"] = {
    "{% if 4 is even %} even {% endif %} [and] {% if 5 is even %} even {% endif %}",
    "even [and]"
}

templates["tests_06"] = {
    [[{% if 4 is iterable %} iterable {% endif %} [and]
    {% if list_1 is iterable %} iterable {% endif %} [and]
    {% if table_1 is iterable %} iterable {% endif %} [and]
    {% if range(1,2) is iterable %} iterable {% endif %}
    ]],
    "[and] iterable [and] iterable [and] iterable"
}

templates["tests_07"] = {
    "{% if 4 is same as(4) %} same {% endif %} [and] {% if table_1 is same as(table_1) %} same {% endif %} [and] {% if 'wow' is same as(table_1) %} same {% endif %}",
    "same [and] same [and]"
}

templates["strip_00"] = {
    "one\n  {{- 1 -}}  \ntwo\n  {{ 2 -}}  \ntree\n  {{- 3 }}  \nfour\n  {{ 4 }}  \nfive",
    "one1two 2tree3 four 4 five",
    expected = "one1two\n  2tree3  \nfour\n  4  \nfive",
}

templates["verbatim_00"] = {
    [[
        [begin]
        {% verbatim %}
            pre if
            {%- if integer_0 -%}
                if body
            {% endif %}
            post if
        {%- endverbatim -%}
        [end]
    ]],
    "[begin] pre if {%- if integer_0 -%} if body {% endif %} post if[end]"
}

templates["with_00"] = {
    [[
        {% with %}
            {% set test = "one" %}
            {{ test }} [and] {{ integer_1 }} [and]
        {% endwith %}
        {{ test }}
    ]],
    "one [and] 1 [and]"
}

templates["with_01"] = {
    [[
        {% with { test: "one" } %}
            {{ test }} [and] {{ integer_1 }} [and]
        {% endwith %}
        {{ test }}
    ]],
    "one [and] 1 [and]"
}

templates["with_02"] = {
    [[
        {% with { test: "one" } only %}
            {{ test }} [and] {{ integer_1 }} [and]
        {% endwith %}
        {{ test }}
    ]],
    "one [and] [and]"
}

templates["with_03"] = {
    [[
        {% set scope = { test: "one" } %}
        {% with scope %}
            {{ test }} [and] {{ integer_1 }} [and]
        {% endwith %}
        {{ test }}
    ]],
    "one [and] 1 [and]"
}

templates["with_04"] = {
    [[
        {% set scope = { test: "one" } %}
        {% with scope only %}
            {{ test }} [and] {{ integer_1 }} [and]
        {% endwith %}
        {{ test }}
    ]],
    "one [and] [and]"
}

templates["error_01"] = {
    [[
        {% if false %}
            nope
        {% endif %}
        {% if true and false %}
            nope
        {% endif %}
        {{ unknown_function() }}
    ]],
    nil,
    "function unknown_function() not found [error_01:7]"
}


local function factory(ops)
    local template = aspect.new(ops or {})
    template.loader = function(name)
        if templates[name] then
            return templates[name][1]
        else
            return nil
        end
    end
    return template
end

describe("Testing compiler.", function()
    local str = "for i,j in vers|select('this', \"oh\") %}"
    it("Checks tokenizer", function()
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

    it("Checks tokenizer with offset", function()

        local tok = tokenizer.new(str, 16) -- goto |

        assert.are.equals(tok:get_token(), "|")
        assert.is.True(tok:is_valid())

        tok:next() -- select
        tok:require("select")
        tok:require_type("word")
    end)

    for _, e in ipairs(ast_expr) do
        it("Checks AST: " .. e.expr, function ()
            local template = factory()
            local ast = astree.new()
            local ok, f = pcall(ast.parse, ast, template.compiler.new(template, "runtime"), tokenizer.new(e.expr))
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

describe("Testing date.", function ()
    local local_offset = date.local_offset
    local local_offset_name = date.get_timezone(local_offset, "", false)
    local offset1600 = 16 * 60 * 60 -- use not existing timezone: +16 UTC
    local offset400 = 4 * 60 * 60

    local dates = {
        -- zero zone
        {"2009-02-13 23:31:30 UTC+00",       1234567890, 0},
        {"2009-02-13T23:31:30+00:00",        1234567890, 0},
        {"Fri, 13 Feb 2009 23:31:30 +0000",  1234567890, 0},
        {"Friday, 13-February-2009 23:31:30 UTC", 1234567890, 0},
        {"2009-02-13T23:31:30+00:00",        1234567890, 0},
        {"Fri, 13 Feb 2009 23:31:30 GMT",    1234567890, 0},
        -- local zone
        {"2009-02-13 23:31:30",               1234567890 - local_offset, local_offset},
        {"2009-02-13T23:31:30",               1234567890 - local_offset, local_offset},
        {"Fri, 13 Feb 2009 23:31:30",         1234567890 - local_offset, local_offset},
        {"Friday, 13-February-2009 23:31:30", 1234567890 - local_offset, local_offset},
        has_utf and {"Пт, 13 Фев 2009 23:31:30",          1234567890 - local_offset, local_offset} or nil,
        has_utf and {"Пятница, 13-Февраль-2009 23:31:30", 1234567890 - local_offset, local_offset} or nil,
        {"2009-02-13T23:31:30",               1234567890 - local_offset, local_offset},
        has_utf and {"Пт, 13 Февраль 2009 23:31:30",      1234567890 - local_offset, local_offset} or nil,
        -- custom zone
        {"2009-02-13 23:31:30 UTC+16",                   1234567890 - offset1600, offset1600},
        {"2009-02-13T23:31:30+16:00",                    1234567890 - offset1600, offset1600},
        {"Fri, 13 Feb 2009 23:31:30 +1600",              1234567890 - offset1600, offset1600},
        {"Friday, 13-February-2009 23:31:30 UTC +16:00", 1234567890 - offset1600, offset1600},
        {"2009-02-13T23:31:30+16:00",                    1234567890 - offset1600, offset1600},
        {"Fri, 13 Feb 2009 23:31:30 GMT+1600",           1234567890 - offset1600, offset1600},
        -- edge cases
        {"00:00:01 UTC", 1, 0},
        {1, 1, 0},
        {"00:00:01", 1-local_offset, local_offset}
    }
    for _, d in ipairs(dates) do
        it("Parse dates " .. d[1], function ()
            local dt = date.new(d[1])
            assert.is.equals(d[2], dt.time, "Time diff: " .. (d[2] - dt.time) .. ". Current: "
                    .. dt.time .. " offset " .. dt.offset .. "; info: " .. dump_table(dt.info))
            assert.is.equals(d[3], dt.offset)
        end)

    end
    local date1 = "2009-02-13 23:31:30 UTC+00"
    local date2 = "2009-02-13T23:31:35+00:00"

    it("Compare dates", function ()

        assert.is.True(date.new(date1) < date.new(date2), date1 .. " < " .. date2)
        assert.is.True(date.new(date1) <= date.new(date2), date1 .. " <= " .. date2)
        assert.is.False(date.new(date1) > date.new(date2), date1 .. " > " .. date2)
        assert.is.False(date.new(date1) >= date.new(date2), date1 .. " >= " .. date2)

        assert.is.False(date.new(date1) == date.new(date2), date1 .. " == " .. date2)
        assert.is.True(date.new(date1) ~= date.new(date2), date1 .. " ~= " .. date2)

        assert.is.True(date.new(date1) == date.new(date1), date1 .. " == " .. date1)
        assert.is.False(date.new(date1) ~= date.new(date1), date1 .. " ~= " .. date1)
    end)

    it("Modify dates", function ()
        assert.is.True(date.new("2019-11-11 09:56:30") > date.new("2019-11-11 09:55:30"), "date('2019-11-11 09:56:30') > date('2019-11-11 09:55:30')")
        assert.is.True(date.new(date1) < date.new(date1) + date.new(1), date1 .. " < " .. date1 .. " + date(1)")
        assert.is.True(date.new(date1) > date.new(date1) - date.new(1), date1 .. " > " .. date1 .. " - date(1)")

        assert.is.True(date.new(date1) < date.new(date1) + date.new("00:00:01 UTC"), date1 .. " < " .. date1 .. " + date(00:00:01 UTC)")
        assert.is.True(date.new(date1) > date.new(date1) - date.new("00:00:01 UTC"), date1 .. " > " .. date1 .. " - date(00:00:01 UTC)")

        assert.is.True(date.new(date1) < date.new(date1) + 1, date1 .. " < " .. date1 .. " + 1")
        assert.is.True(date.new(date1) > date.new(date1) - 1, date1 .. " > " .. date1 .. " - 1")

        assert.is.True(date.new(date1) < date.new(date1) + {sec = 1},  date1 .. " < " .. date1 .. " + {sec = 1}")
        assert.is.True(date.new(date1) < date.new(date1) + {sec = -1}, date1 .. " > " .. date1 .. " + {sec = -1}")
        assert.is.True(date.new(date1) > date.new(date1) - {sec = 1},  date1 .. " > " .. date1 .. " - {sec = 1}")
        assert.is.True(date.new(date1) > date.new(date1) - {sec = -1}, date1 .. " < " .. date1 .. " - {sec = -1}")
    end)

    local formated = {
        -- zero zone
        {
            name = "zero zone",
            date = "2009-02-13 23:31:30 UTC+0000",
            format = {
                {"%F %T", os.date("%F %T", 1234567890)},
                {"!%F %T", "2009-02-13 23:31:30"},
                {"%F %T UTC%z", os.date("%F %T UTC%z", 1234567890)},
                {"!%F %T UTC%z", "2009-02-13 23:31:30 UTC+0000"},
            }
        },
        -- custom zone
        {
            name = "custom zone",
            date = "2009-02-13 23:31:30 UTC+16",
            format = {
                { "%F %T UTC%Z", "2009-02-13 23:31:30 UTC+16", offset1600 }, -- UTC+16
                { "!%F %T UTC%Z", "2009-02-13 07:31:30 UTC", offset1600 }, -- UTC+0 time
                { "%F %T UTC%Z", "2009-02-13 07:31:30 UTC", 0}, -- UTC+0 time
                { "!%F %T UTC%Z", "2009-02-13 07:31:30 UTC", 0}, -- UTC+0 time
                { "%F %T UTC%Z", "2009-02-13 11:31:30 UTC+4", offset400 }, -- UTC+4 time
                { "!%F %T UTC%Z", "2009-02-13 07:31:30 UTC", offset400 }, -- UTC+4 time
                { "%F %T UTC"..local_offset_name, os.date("!%F %T UTC%z", 1234567890 + local_offset - offset1600), nil},
                { "!%F %T UTC%Z", os.date("!%F %T UTC", 1234567890 - offset1600), nil},
            }
        },
        -- locale
        {
            name = "locale",
            date = "2009-02-13 23:31:30 UTC+00",
            format = {
                {"%a, %d %b", "Пт, 13 Фев", 0, 'ru'},
                {"%A, %d %B", "Пятница, 13 Февраль", 0, 'ru'},
                {"%a, %d %b", "Fri, 13 Feb", 0, 'en'},
                {"%A, %d %B", "Friday, 13 February", 0, 'en'},
                {"%a, %d %b", "Fri, 13 Feb", 0},
                {"%A, %d %B", "Friday, 13 February", 0},
            }
        },
    }
    for _, v1 in ipairs(formated) do
        for _, v2 in ipairs(v1.format) do
            it("Formatting [" .. v1.name .. "] date '" .. v1.date .. "' as '" .. v2[1]
                .. "' with offset " .. tostring(v2[2])
                .. " and locale " ..tostring(v2[4]), function ()
                local d = date.new(v1.date)
                assert.is.equals(v2[2], d:format(v2[1], v2[3], v2[4]))
            end)
        end
    end
end)

describe("Testing template syntax.", function ()
    for k, v in sort(templates) do
        local template = factory(v[4] or {})
        local compiled = {}
        template.luacode_save = function (name, code)
            compiled[#compiled + 1] = code
        end
        it("Run template " .. k, function ()
            compiled = {}
            local result, err = template:render(k, vars)
            if result and not err then
                assert.is.equals(v[2], spaceless(result.result), "Test template ".. k ..":\n" .. v[1] .. "\nCompiled template:\n" .. table.concat(compiled))
            elseif not v[2] and v[3] then
                assert.is.equals(err.message .. " [" .. err.name .. ":" .. err.line .. "]", v[3])
            else
                error(tostring(err) .. "\n\nTest template ".. k ..":\n" .. numerate_lines(v[1])
                        .. "\nCompiled template " .. k .. ":\n" .. numerate_lines(table.concat(compiled)))
            end
        end)
    end

    it("Test batch filter", function()
        local m = {}
        local iter = batch.new({"a", "b", "c", "d", "e"}, 2)
        for _, list in getmetatable(iter).__pairs(iter) do
            local n = {}
            for i,j in sort(list) do
                table.insert(n, i .. ":" .. j)
            end
            table.insert(m, table.concat(n, ","))
        end
        assert.is.equals("1:a,2:b [and] 3:c,4:d [and] 5:e", table.concat(m, " [and] "))
    end)

    it("Render block", function ()
        local template = factory()

        assert.is.equals("block one", strip(template:render_block("extends_01", "one", vars)))
    end)

    it("Render macro", function ()
        local template = factory()

        assert.is.equals("[macro: check]", strip(template:render_macro("macro_01", "key_value", {key = "macro", value = "check"})))
    end)

    it("Strip spaces", function ()
        local template = factory()

        assert.is.equals(templates["strip_00"].expected, template:render("strip_00", vars).result)
    end)
end)

describe("Testing cache.", function ()
    it("bytecode and luacode cache", function ()
        local template = aspect.new()
        local i, luacode, bytecode = 0
        template.loader = function(name)
            i = i + 10000
            if templates[name] then
                return templates[name][1]
            else
                return nil
            end
        end

        template.bytecode_load = function (name)
            assert.is.equals("basic_00", name)
            i = i + 1
            return bytecode
        end
        template.luacode_load = function (name)
            assert.is.equals("basic_00", name)
            i = i + 100
            return luacode
        end
        template.bytecode_save = function (name, code)
            assert.is.equals("basic_00", name)
            assert.is_true(string.len(code) > 0)
            bytecode = code
            i = i + 10
            return nil
        end
        template.luacode_save = function (name, code)
            assert.is.equals("basic_00", name)
            assert.is_true(string.len(code) > 0)
            luacode = code
            i = i + 1000
            return nil
        end


        assert.is.equals("1 and 2 and string and 17", strip(template:render("basic_00", vars).result))
        assert.is.equals(11111, i, "not all cache functions called. [1] call")

        template.cache = {}
        i = 0
        assert.is.equals("1 and 2 and string and 17", strip(template:render("basic_00", vars).result))
        assert.is.equals(1, i, "not all cache functions called. [2] call")

        template.cache = {}
        bytecode = nil
        i = 0
        assert.is.equals("1 and 2 and string and 17", strip(template:render("basic_00", vars).result))
        assert.is.equals(111, i, "not all cache functions called. [3] call")
    end)
end)

describe("Testing CLI.", function ()
    it("Basic usage command", function ()
        local cli = require("aspect.cli")

        local code, message = cli.run({
            "--include=spec/fixture",
            "spec/fixture/data.json",
            "spec/fixture/greeting.view"
        })
        assert.is.equals(0, code)
        assert.is.equals(message, [[
Hello, nobody!
We sent foo to email@dev.null.

Footer say foo.]])
    end)
end)