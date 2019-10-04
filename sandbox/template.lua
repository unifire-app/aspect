local factory = function ()
    local _self = {
        name = "example.tpl",
        blocks = {},
        macros = {},
        includes = {},
        imports = {},
        _include = (...).include,
        _fetch = (...).fetch,
        _import = (...).fetch,
    }

    function _self.body(__, ...)
        _context = ...
        --local _macros = _self.template("macros.tpl")
        __.line = 1

        --_self.import("")

        local some_macro = "doode"
        __("Hello world!")


        print(_self.name)
        _self.macros['form']({['name'] = some_macro}, __)
    end

    --- {% block content %}
    function _self.blocks.content(__, ...)
        _context = ...
        _line = 13
        __("Content block")
    end
    --- {% endblock %}

    --- {% macro form(name="undefined") %}
    function _self.macros.form(__, ...)
        _context = ...
        local name = _context["name"] or "undefined"
        _line = 6
        __("<input type=text value='")
        __(name)
        __("'><button type=submit>submit</button>")
    end
    --- {% endmacro %}


    return _self
end
