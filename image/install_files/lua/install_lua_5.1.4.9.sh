#!/bin/bash
cd /opt/apps/install
tar xf lua-5.1.4.9.tar.bz2
cd /opt/apps/install/lua-5.1.4.9
./configure --prefix /opt/apps/lua/5.1.4.9
make
make install
ln -s /opt/apps/lua/5.1.4.9 /opt/apps/lua/lua
ln -s /opt/apps/lua/lua/bin/lua /usr/local/bin
ln -s /opt/apps/lua/lua/bin/luac /usr/local/bin
