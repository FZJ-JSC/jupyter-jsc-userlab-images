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
  mkdir -p ${DIR}/logs
  export JUPYTER_LOG_DIR=${DIR}/logs
  export JUPYTER_STDOUT=${JUPYTER_LOG_DIR}/stderr
  export PYTHONNOUSERSITE=1
  export JUPYTERJSC_USER_CMD="jupyterhub-singleuser"
  export MODULEPATH=/p/software/jsccloud/productionstages
  export OTHERSTAGES=/p/software/jsccloud/productionstages
  API_URL_WITHOUT_PROTO=${JUPYTERHUB_API_URL##https\:\/\/}
  export JUPYTERHUB_DOMAIN=${API_URL_WITHOUT_PROTO%%\/*}
  export JUPYTER_SERVER_PUBLIC_URL="https://${JUPYTERHUB_DOMAIN}${JUPYTERHUB_SERVICE_PREFIX}"
  export DWAVE_INSPECTOR_JUPYTER_SERVER_PROXY_EXTERNAL_URL=${JUPYTER_SERVER_PUBLIC_URL}
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
    CMD=$(python3 /tmp/custom/uftp.py)
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
  if [[ -f /tmp/custom/mount_home_ro.sh ]]; then
    /bin/bash /tmp/custom/mount_home_ro.sh 
  fi
  if [[ -f /tmp/custom/mount_project_ro.sh ]]; then
    /bin/bash /tmp/custom/mount_project_ro.sh 
  fi
  if [[ -f /tmp/custom/mount_data_ro.sh ]]; then
    /bin/bash /tmp/custom/mount_data_ro.sh 
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

cleanup () {
  echo "$(date) - Start cleanup."
  # Send Cancel to JupyterHub, this way we can use restartPolicy: Always
  # to "survive" VM reboots, but do not always restart properly stopped
  # labs.
  curl -X "POST" -d '{"failed": true, "progress": 100, "html_message": "<details><summary>Cleanup successful.</summary>Post stop hook ran successful</details>"}' ${JUPYTERHUB_EVENTS_URL}

  mount | grep "/mnt/B2DROP" > /dev/null
  EC=$?
  if [[ $EC -eq 0 ]]; then
    echo "$(date) - Unmounted /mnt/B2DROP."
  else
    echo "$(date) - B2DROP not mounted, do not unmount."
  fi

  mount | grep "/mnt/JUST_HOME" > /dev/null
  EC=$?
  if [[ $EC -eq 0 ]]; then
    echo "$(date) - Unmounted /mnt/JUST_HOME."
  else
    echo "$(date) - JUST not mounted, do not unmount."
  fi

  echo "$(date) - Cleanup done."
}

update_config () {
  # We have to copy the config.py file, because it's mounted as read-only
  if [[ -f ${DIR}/config.py ]]; then
    cp ${DIR}/config.py /tmp/config.py
    chmod +w /tmp/config.py
    sed -i -e "s|_servername_|${JUPYTERHUB_SERVER_NAME}|g" /tmp/config.py
  else
    # Otherwise the CMD in Dockerfile would not work correctly
    # If other values are required, one can add a default config.py, this is
    # just the fallback solution
    chmod +w /tmp/config.py
    echo "c.ServerApp.root_dir = \"/\"" >> /tmp/config.py
  fi
  if [[ -f ${EBROOTJUPYTERLAB}/etc/jupyter/jupyter_notebook_config.py ]]; then
    echo "$(date) - Add system specific config ..."
    echo "" >> /tmp/config.py
    cat ${EBROOTJUPYTERLAB}/etc/jupyter/jupyter_notebook_config.py >> /tmp/config.py
    for path in ${JUPYTER_EXTRA_LABEXTENSIONS_PATH//:/$'\n'}; do
      echo "c.LabServerApp.extra_labextensions_path.append('$path')" >> /tmp/config.py
    done
    echo "$(date) - Add system specific config done"
  fi
  if [[ -f /home/jovyan/.jupyter/config.py ]]; then
    ## Add your own stuff to the config
    echo "" >> /tmp/config.py
    cat /home/jovyan/.jupyter/config.py >> /tmp/config.py
  fi
  if [[ -f ${EBROOTJUPYTERLAB}/bin/update_favorites_json ]]; then
    # update favorite-dirs with $HOME,$PROJECT,$SCRATCH,
    echo "$(date) - Update favorites"
    ${EBROOTJUPYTERLAB}/bin/update_favorites_json
  fi
}

start () {
  echo "$(date) - Start ${JUPYTERJSC_USER_CMD} with args ${@} ..."
  ${JUPYTERJSC_USER_CMD} --config /tmp/config.py ${@} 2>&1 | tee ${JUPYTER_LOG_DIR}/stdout
  echo "$(date) - Start ${JUPYTERJSC_USER_CMD} done" 
}

requirements
set_env
load_modules
mount_b2drop
mount_just
update_config
start
cleanup
