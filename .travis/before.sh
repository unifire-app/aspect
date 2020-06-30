#!/bin/bash

set -ex

luarocks install busted
luarocks install cluacov
luarocks install lua-cjson $LUA_CJSON
luarocks install luautf8
