#!/bin/bash
cd /opt/apps/install
tar xzf Lmod-8.7.67.tar.gz
cd /opt/apps/install/Lmod-8.7.67
./configure --prefix /opt/apps
make install
ln -s /opt/apps/lmod/lmod/init/profile /etc/profile.d/z00_lmod.sh 
ln -s /opt/apps/lmod/lmod/init/cshrc   /etc/profile.d/z00_lmod.csh
