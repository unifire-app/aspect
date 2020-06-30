#!/bin/bash

set -ex

luarocks install busted
luarocks install cluacov
luarocks install lua-cjson $LUA_CJSON
# lua 5.3+ already has utf8 module
lua -e 'if utf8 then os.exit(1) else os.exit(0) end' && luarocks install utf8; true
