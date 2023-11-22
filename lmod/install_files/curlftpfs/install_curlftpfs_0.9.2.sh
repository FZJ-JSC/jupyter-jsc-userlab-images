#!/bin/bash
cd /opt/apps/install
tar xf curlftpfs-0.9.2.tar.gz
cd /opt/apps/install/curlftpfs-0.9.2
./configure --prefix /opt/apps/curlftpfs --build=x86_64-unknown-linux-gnu
make
make install
ln -s /opt/apps/curlftpfs/bin/curlftpfs /usr/local/bin
