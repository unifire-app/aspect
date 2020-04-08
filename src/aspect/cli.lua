local parse_args = require("pl.app").parse_args
local file       = require("pl.file")
local var_dump   = require("aspect.utils").var_dump
local dump       = require("aspect.utils").dump
local aspect     = require("aspect.template")
local fs_loader  = require("aspect.loader.filesystem")

local arg        = arg or {}
local cjson      = require("cjson.safe")
local aliases = {
    l = "lint",
    d = "debug",
    I = "include",
    h = "help",
    e = "escape",
}

return function ()
    local autoescape, err = false, nil
    local options = parse_args(nil, {include = true, I = true})
    for k, v in pairs(options) do
        if aliases[k] then
            options[aliases[k]] = v
        end
    end
    if options.help or #arg < 2 then
        io.stdout:write("Aspect " .. aspect._VERSION .. ", the template engine.\n\n" ..[[
Usage:  aspect [options] data_file template_name
Syntax: https://github.com/unifire-app/aspect/blob/master/docs/syntax.md

Params
  data_file      path to file with fixture (json or lua format)
  template_name  path or name of the template for rendering
  ----
  Use '-' instead of data_file or template_name for reading from stdin.

Options
  --help           -h       print this help
  --include=<dir>  -I<dir>  use <dir> for loading other templates
  --escape         -e       enables auto-escaping with 'html' strategy.
  --lint           -l       just lint the template
  --debug          -d       print debug information

Examples

Render JSON file to STDOUT or file:
  $ aspect path/to/fixture.json path/to/template.tmpl
  $ aspect path/to/fixture.json path/to/template.tmpl >path/to/result.txt

Render data from STDIN:
  $ aspect - path/to/template.tmpl

Read template from STDOUT:
  $ aspect path/to/fixture.json -

Lint the template:
  $ aspect --lint path/to/template.tmpl
]])
        os.exit()
    end
    local function verbose(...)
        io.stderr:write("[DEBUG] " .. dump(...) .. "\n")
    end

    if options.escape then
        autoescape = true
    end

    local template_file, template, tpl, loader, build = arg[#arg], nil, nil, nil, nil
    local data_file, data = arg[#arg - 1], nil

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
        template, err = file.read(template_file)
    end
    if not template or template == "" then
        if err then
            io.stderr:write("[ERROR] Failed to load template: " .. err .. "\n")
        else
            io.stderr:write("[ERROR] Failed to load template\n")
        end
        os.exit(1)
    end
    if options.debug then
        verbose("template (" .. string.len(template) .. " bytes): ", template)
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
        io.stderr:write("[ERROR] Failed to load and compile template: " .. tostring(err) .. "\n")
        os.exit(1)
    end
    if options.debug then
        verbose("template code: ", build:get_code())
    end
    if options.lint then
        os.exit(0)
    end

    --- Read data
    if data_file == '-' and not template then
        if options.debug then
            verbose("reading data from STDIN")
        end
        data, err = io.stdin:read("*a")
    else
        if options.debug then
            verbose("reading data from " .. tostring(data_file))
        end
        data, err = file.read(data_file)
    end
    if not data or data == "" then
        if err then
            io.stderr:write("[ERROR] Failed to read data: " .. err .. "\n")
        else
            io.stderr:write("[ERROR] Failed to read data\n")
        end
        os.exit(1)
    end
    if options.debug then
        verbose("data (" .. string.len(data) .. " bytes): ", data)
    end
    data, err = cjson.decode(data)
    if not data then
        io.stderr:write("[ERROR] Failed to decode data: " .. tostring(err) .. "\n")
        os.exit(1)
    end

    output, err = templater:render(template_file, data, {
        autoescape = autoescape
    })
    if err then
        io.stderr:write("[ERROR] Failed to render template: " .. tostring(err) .. "\n")
        os.exit(1)
    end
    io.stdout:write(tostring(output))
end