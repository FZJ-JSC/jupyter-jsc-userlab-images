#!/bin/bash

# add JUST_HOME support
JUST_HOME_PATH=/mnt/JUST_HOME
mkdir -p ${JUST_HOME_PATH}
chown ${NB_UID}:${NB_GID} ${JUST_HOME_PATH}

mkdir -p /p/data1
chown ${NB_UID}:${NB_GID} /p/data1

mkdir -p /p/project1
chown ${NB_UID}:${NB_GID} /p/project1

mkdir -p /p/home/jusers
chown ${NB_UID}:${NB_GID} /p/home/jusers

## add B2DROP support
B2DROP_PATH=/mnt/B2DROP
mkdir -p ${B2DROP_PATH}
chown ${NB_UID}:${NB_GID} ${B2DROP_PATH}


usermod -aG davfs2 ${NB_UID}
echo "https://b2drop.eudat.eu/remote.php/webdav ${B2DROP_PATH} davfs user,rw,noauto 0 0" >> /etc/fstab
chmod u+s /usr/sbin/mount.davfs
