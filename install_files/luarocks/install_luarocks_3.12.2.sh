#!/bin/bash
cd /opt/apps/install
tar xzf luarocks-3.12.2.tar.gz
cd luarocks-3.12.2
./configure
make
make install
export LUA_PATH="$LUAROCKS_PREFIX/share/lua/5.3/?.lua;$LUAROCKS_PREFIX/share/lua/5.3/?/init.lua;;"
export LUA_CPATH="$LUAROCKS_PREFIX/lib/lua/5.3/?.so;;"
luarocks install luaposix
