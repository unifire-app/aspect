local var_dump   = require("aspect.utils").var_dump
local dump       = require("aspect.utils").dump
local numerate   = require("aspect.utils").numerate_lines
local get_keys   = require("aspect.utils").keys
local aspect     = require("aspect.template")
local fs_loader  = require("aspect.loader.filesystem")
local json       = require("aspect.config").json
local table      = table

local cli = {
    aliases = {
        lint = true,
        l = "lint",

        debug = true,
        d = "debug",

        include = true,
        I = "include",

        help = true,
        h = "help",

        escape = true,
        e = "escape",

        dump = true,
        p = "dump",

        arg = true,
        a = "arg"
    }
}

--- @param arguments table list of arguments
--- @param aliases table list of possible arguments and short aliases
--- @param with_values table arguments with values
--- @return table with arguments and values (true - if no value)
--- @return table list of paths at the end
--- @return string error
function cli.parse_args(arguments, aliases, with_values)
    with_values = with_values or {}
    aliases = aliases or {}
    local vals, paths, i = {}, {}, 1
    while i <= #arguments do
        local arg = arguments[i]
        local prefix, _name, value = arg:match("^(%-%-?)([%a_-]+)=?(.*)")
        if value == "" then
            value = nil
        end
        if prefix and #paths == 0 then
            if aliases[_name] then
                local name
                if prefix == "-" and aliases[_name] ~= true then -- this is alias
                    name = aliases[_name]
                else
                    name = _name
                end
                if with_values[name] and value then
                    vals[name] = value
                elseif with_values[name] and not value then
                    if not arguments[i + 1] or (arguments[i + 1] and arguments[i + 1]:match("^%-")) then
                        return nil, nil, "no value for '".. _name .. "'"
                    end
                    if vals[name] then
                        if type(vals[name]) ~= "table" then
                            vals[name] = {vals[name]}
                        end
                        table.insert(vals[name], arguments[i + 1])
                    else
                        vals[name] = arguments[i + 1]
                    end
                    i = i + 1
                elseif not with_values[name] and value then
                    return nil, nil, "flag '" .. _name .. "' should be without value"
                else
                    vals[name] = true
                end
            else
                return nil, nil, "unknown flag '" .. _name .. "'"
            end
        else
            table.insert(paths, 1, arg)
        end
        i = i + 1
    end
    return vals, paths
end

--- Read whole file
--- @param path string file path
--- @return string data
--- @return string error
function cli.read_file(path)
    local f, err, data
    f, err = io.open(path, "rb")
    if err then
        return nil, err
    end
    data, err = f:read("*all")
    if err then
        return nil, err
    end
    f:close()
    if not data or data == "" then
        return nil, "empty file"
    end
    return data
end

function cli.run(arguments)
    arguments = arguments or {}
    local autoescape = false
    local options, paths, err = cli.parse_args(arguments, cli.aliases, {include = true, arg = true} )
    if err then
        return 1, "[ERROR] " .. err
    end
    --local options = parse_args(arguments, {include = true, I = true})
    --for k, v in pairs(options) do
    --    if cli.aliases[k] then
    --        options[cli.aliases[k]] = v
    --    end
    --end
    if options.help or #arguments < 2 then
        return 0, "Aspect " .. aspect._VERSION .. ", the template engine.\n\n" ..[[
Usage:  aspect [options] data_file template_name
Syntax: https://github.com/unifire-app/aspect/blob/master/docs/syntax.md

Params:
  data_file      path to file with fixture (json)
  template_name  path or name of the template for rendering

Options:
  --help           -h       print this help
  --include <dir>  -I<dir>  use <dir> for loading other templates
  --escape         -e       enables auto-escaping with 'html' strategy.
  --lint                    just lint the template
  --dump                    dump information about template
  --debug          -d       print debug information
  --arg            -a       argument

Examples:
  Render JSON file to STDOUT or file:
    $ aspect path/to/fixture.json path/to/template.tmpl
    $ aspect path/to/fixture.json path/to/template.tmpl >path/to/result.txt

  Render data from STDIN (using -):
    $ aspect - path/to/template.tmpl

  Read template from STDIN (using -):
    $ aspect path/to/fixture.json -

  Lint the template:
    $ aspect --lint path/to/template.tmpl
]]
    end
    local function verbose(...)
        io.stderr:write("[DEBUG] " .. dump(...) .. "\n")
    end

    if options.debug then
        verbose("command options", options)
    end

    if options.escape then
        autoescape = true
    end

    local template_file, template, tpl, loader = paths[1], nil, nil, nil
    --- @type aspect.compiler
    local build
    local data_file, data = paths[2], nil

    --- Select template
    local output
    local templater = aspect.new()
    if template_file == '-' then
        if options.debug then
            verbose("loading template from STDIN")
        end
        template, err = io.stdin:read("*a")
        template_file = "STDIN"
    else
        if options.debug then
            verbose("loading template from " .. tostring(template_file))
        end
        template, err = cli.read_file(template_file)
    end
    if err then
        return 1, "[ERROR] Failed to load template: " .. err
    end
    if options.debug then
        verbose("template (" .. string.len(template) .. " bytes): ", numerate(template))
    end
    if options.include then
        if options.debug then
            verbose("enable loader from " .. tostring(options.include))
        end
        loader = fs_loader.new(options.include)
    end
    templater.loader = function(name, t)
        if name == template_file then
            return template
        elseif loader then
            return loader(name, t)
        end
    end
    tpl, err, build = templater:load(template_file)
    if err then
        return 1, "[ERROR] Failed to load and compile template: " .. tostring(err)
    end
    if options.debug then
        verbose("template code: ", numerate(build:get_code()))
    end
    if options.lint then
        return 0
    end
    if options.dump then
        local out = {}
        table.insert(out, "REFS:" .. dump(build.ctx.tpl_refs))
        table.insert(out, "VARS:" .. dump(build.ctx.var_refs))
        if next(build.blocks) then
            for bn, b in pairs(build.blocks) do
                table.insert(out, "BLOCK: " .. bn)
                table.insert(out, " DESCR: " .. (b.desc or "<none>"))
                table.insert(out, " LOCATION: "
                    .. b.start_line .. "-" .. b.end_line .. " lines or " .. b.start_pos .. "-" .. b.end_pos .. " bytes")
                table.insert(out, " REFS: " .. dump(b.ctx.tpl_refs))
                table.insert(out, " VARS " .. dump(b.ctx.var_refs))
            end
        end
        if next(build.macros) then
            for mn, m in pairs(build.macros) do
                table.insert(out, "MACRO: " .. mn)
                table.insert(out, " DESCR: " .. (m.desc or "<none>"))
                table.insert(out, " LOCATION: "
                        .. m.start_line .. "-" .. m.end_line .. " lines")
                table.insert(out, " ARGS: " .. dump(m.args))
                table.insert(out, " REFS: " .. dump(m.ctx.tpl_refs))
                table.insert(out, " VARS " .. dump(m.ctx.var_refs))
            end
        end
        --if next(build.refs) then
        --    table.insert(out, "REFS:")
        --    for tn, t in pairs(build.refs) do
        --        table.insert(out, "  " .. tn .. ": " .. table.concat(get_keys(t), ", "))
        --    end
        --end
        --for bn, b in pairs(build.blocks) do
        --    table.insert(out, "BLOCK: " .. bn)
        --    table.insert(out, "  lines: " .. b.start_line .. "-" .. b.end_line)
        --    table.insert(out, "  use parent(): " .. (b.parent and 'yes' or 'no'))
        --    if next(b.used_vars) then
        --        table.insert(out, "  used variables: ")
        --        for vn, v in pairs(b.used_vars) do
        --            table.insert(out, "    " .. vn .. ":")
        --            local keys = get_keys(v.keys)
        --            if #keys > 0 then
        --                table.insert(out, "      keys: " .. table.concat(keys, ", "))
        --            end
        --            table.insert(out, "      where: ")
        --            for _, w in pairs(v.where) do
        --                table.insert(out, "        - " .. template_file .. ":" .. w.line .. " in tag " .. (w.tag or "--"))
        --            end
        --        end
        --    end
        --    --table.insert(out, "Block " .. bn .. ", lines " .. b.start_line .. "-" .. b.end_line .. ": " .. dump(b))
        --end
        --for mn, m in pairs(build.blocks) do
        --
        --end
        table.insert(out, "TEMPLATE:")
        table.insert(out, numerate(template, "  "))
        table.insert(out, "CODE:")
        table.insert(out, numerate(build:get_code(), "  "))
        return 0, table.concat(out, "\n")
    end

    --- Read data
    if data_file == '-' and not template then
        if options.debug then
            verbose("reading data from STDIN")
        end
        data, err = io.stdin:read("*a")
        data_file = "STDIN"
    else
        if options.debug then
            verbose("reading data from " .. tostring(data_file))
        end
        data, err = cli.read_file(data_file)
    end
    if err then
        return 1, "[ERROR] Failed to read data: " .. err
    end
    if options.debug then
        verbose("data (" .. string.len(data) .. " bytes): ", data)
    end
    if not json.decode then
        return 1, "[ERROR] " .. json.error
    end
    data, err = json.decode(data)
    if not data then
        return 1, "[ERROR] Failed to decode data: " .. tostring(err)
    end

    output, err = templater:render(template_file, data, {
        autoescape = autoescape
    })
    if err then
        return 1, "[ERROR] Failed to render template: " .. tostring(err)
    end
    return 0, tostring(output)
end

function cli.shell()
    local code, result = cli.run(_G.arg or {})
    if code == 0 then
        if result then
            io.stdout:write(result)
        end
        os.exit(0)
    else
        io.stderr:write(result .. "\n")
        os.exit(code)
    end
end

return cli