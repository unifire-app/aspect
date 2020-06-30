#!/bin/bash

set -ex

luarocks install busted
luarocks install cluacov
luarocks install lua-cjson $LUA_CJSON
# lua 5.3+ already has utf8 module
luarocks install utf8; true
