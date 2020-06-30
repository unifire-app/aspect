#!/bin/bash

set -ex

echo "Install busted ..."
luarocks install busted
echo "Install cluacov ..."
luarocks install cluacov
echo "Install lua-cjson $LUA_CJSON..."
luarocks install lua-cjson $LUA_CJSON
echo "Check and install utf8 module..."
# lua 5.3+ already has utf8 module
lua -e 'if utf8 then os.exit(1) else os.exit(0) end' && luarocks install utf8
