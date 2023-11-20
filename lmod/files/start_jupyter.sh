#!/bin/bash

requirements () {
  echo "$(date) - Setup system specific requirements ..."
  source /opt/apps/lmod/lmod/init/profile
  echo "$(date) - Setup system specific requirements done"
}

set_env() {
  echo "$(date) - Set environment variables ..."
  export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
  export LC_ALL=en_US.UTF-8
  export JUPYTER_LOG_DIR=${DIR}
  export JUPYTER_STDOUT=${JUPYTER_LOG_DIR}/stderr
  export PYTHONNOUSERSITE=1
  export MODULEPATH=/p/software/jsccloud/productionstages
  export OTHERSTAGES=/p/software/jsccloud/productionstages
  echo "$(date) - Set environment variables done" 
}

mount_b2drop () {
  echo "$(date) - Mount B2DROP ..."
  mount | grep "/mnt/B2DROP" > /dev/null
  EC=$?
  if [[ $EC -eq 0 ]]; then
    echo "$(date) - /mnt/B2DROP is already mounted."
  else
    if [[ -f /home/jovyan/.davfs2/secrets ]]; then
      cat /home/jovyan/.davfs2/secrets | grep "https://b2drop.eudat.eu/remote.php/webdav" &> /dev/null
      EC=$?
      if [[ $EC -eq 0 ]]; then
        mount /mnt/B2DROP
      else
        echo "$(date) - Secret is not stored. Do not auto mount B2DROP."
      fi
    fi
  fi
  echo "$(date) - Mount B2DROP done"
}

mount_just () {
  echo "$(date) - Mount JUST ..."
  mount | grep "/mnt/JUST_HOME" > /dev/null
  EC=$?
  if [[ $EC -eq 0 ]];then
    echo "/mnt/JUST_HOME is already mounted"
  else
    CMD=$(python3 /tmp/input/bin/uftp.py)
    EC=$?
    if [[ $EC -eq 0 ]]; then
      $CMD /mnt/JUST_HOME 2>/dev/null
      EC=$?
      if [[ $EC -eq 0 ]]; then
        if [[ -L /home/jovyan/JUST_HOMEs_readonly && -d /home/jovyan/JUST_HOMEs_readonly ]]; then
          :
        else
          if [[ -L /home/jovyan/JUST_HOMEs_readonly ]]; then
            unlink /home/jovyan/JUST_HOMEs_readonly
          fi
          ln -s /mnt/JUST_HOME /home/jovyan/JUST_HOMEs_readonly
          EC=$?
          if [[ $EC -eq 0 ]]; then
            echo "$(date) - JUST mounted to /home/jovyan/JUST_HOMEs_readonly"
          else
            echo "$(date) - JUST mounted to /mnt/JUST_HOME"
          fi
        fi
      else
        echo "$(date) - JUST mount failed."
      fi
    else
      echo "$(date) - Python script ended with exit code $EC"
    fi
  fi
  echo "$(date) - Mount JUST done"
}

load_modules () {
  echo "$(date) - Load modules ..."

  JUPYTER_VERSION_MODULES_FILE=/tmp/custom/load_jupyter_version.sh
  JUPYTER_USER_MODULES_FILE=/tmp/custom/load_jupyter_modules.sh

  if [ -f $JUPYTER_VERSION_MODULES_FILE ]; then
    source $JUPYTER_VERSION_MODULES_FILE
  else
    echo "File $JUPYTER_VERSION_MODULES_FILE does not exist. Please ensure it exists."
    exit 1
  fi
  if [ -f $JUPYTER_USER_MODULES_FILE ]; then
    source $JUPYTER_USER_MODULES_FILE
  else
    echo "File $JUPYTER_USER_MODULES_FILE does not exist. Not loading user specified modules."
  fi

  echo "$(date) - Load modules done"
}

start () {
  echo "$(date) - Start jupyterhub-singleuser ..."
  timeout 2min jupyterhub-singleuser 2>${DIR}/stderr 1>${DIR}/stdout
  echo "$(date) - Start jupyterhub-singleuser done" 
}

requirements
set_env
load_modules
# mount_b2drop
# mount_just
start
