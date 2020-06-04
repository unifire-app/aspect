local aspect = require("aspect.template")
local var_dump = require("aspect.utils").var_dump
local table_new = table.new or function () return {} end
local os = os

return function (iterations)
    iterations = iterations or 1000
    local gc = collectgarbage
    local total = 0
    local template = aspect.new({
        cache = true,
        loader = function (name)
            var_dump("load ", name)
            os.exit()
        end
    })
    --local parse = template.parse
    --local compile = template.compile
    local view = [[
    <ul>
    {% for k, v in context%}
        <li>{{v}}</li>
    {% endfor %}
    </ul>]]

    print(string.format("Running %d iterations in each test", iterations))

    local cmp, err = template:parse("runtime", view) -- warm up and check syntax
    if err then
        print("Parse error: " .. tostring(err), "Template: " .. view)
        os.exit()
    end

    gc()
    gc()

    local x = os.clock()
    for _ = 1, iterations do
        template:parse("runtime", view)
    end
    local z = os.clock() - x
    print(string.format("    Parsing Time: %.6f", z))
    total = total + z

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        template:compile("runtime", view, false)
    end
    z = os.clock() - x
    print(string.format("Compilation Time: %.6f (template)", z))
    total = total + z

    template.cache = {}
    template:compile("runtime", view, true)

    gc()
    gc()


    x = os.clock()
    for _ = 1, iterations do
        template:get_view("runtime")
    end
    z = os.clock() - x
    print(string.format("Compilation Time: %.6f (template, cached)", z))
    total = total + z

    local context = { "Emma", "James", "Nicholas", "Mary" }

    template.cache = {}

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        template:eval("runtime", view, context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (same template)", z))
    total = total + z

    template.cache = {}
    template:compile("runtime", view, true)

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        template:render("runtime", context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (same template, cached)", z))
    total = total + z

    template.cache = {}

    local views = table_new(iterations, 0)
    for i = 1, iterations do
        views[i] = "<h1>Iteration " .. i .. "</h1>\n" .. view
    end

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        template:eval("runtime" .. i, views[i], context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template)", z))
    total = total + z

    for i = 1, iterations do
        template:compile("runtime" .. i, views[i], true)
    end
    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        template:render("runtime" .. i, context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, cached)", z))
    total = total + z

    local contexts = table_new(iterations, 0)

    for i = 1, iterations do
        contexts[i] = { "Emma", "James", "Nicholas", "Mary" }
    end

    template.cache = {}

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        template:eval("runtime" .. i, views[i], contexts[i])
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, different context)", z))
    total = total + z

    for i = 1, iterations do
        template:compile("runtime" .. i, views[i], true)
    end

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        template:render("runtime" .. i, contexts[i])
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, different context, cached)", z))
    total = total + z
    print(string.format("      Total Time: %.6f", total))
end