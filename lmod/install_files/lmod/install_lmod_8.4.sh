#!/bin/bash
cd /opt/apps/install
tar xf lmod-8.4.tar.bz2
cd /opt/apps/install/Lmod-8.4
./configure --prefix /opt/apps
make install
ln -s /opt/apps/lmod/lmod/init/profile /etc/profile.d/z00_lmod.sh 
ln -s /opt/apps/lmod/lmod/init/cshrc   /etc/profile.d/z00_lmod.csh
