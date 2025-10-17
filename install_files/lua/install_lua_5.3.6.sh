#!/bin/bash
cd /opt/apps/install
tar xzf lua-5.3.6.tar.gz
cd /opt/apps/install/lua-5.3.6
make linux install INSTALL_TOP=/opt/apps/lua/5.3.6
ln -s /opt/apps/lua/5.3.6 /opt/apps/lua/lua
ln -s /opt/apps/lua/5.3.6/bin/lua /usr/local/bin
ln -s /opt/apps/lua/5.3.6/bin/luac /usr/local/bin
