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
  export JUPYTER_CONFIG_PATH="${JUPYTER_CONFIG_PATH:+$JUPYTER_CONFIG_PATH:}/mnt/datamount_start"
  export DWAVE_INSPECTOR_JUPYTER_SERVER_PROXY_EXTERNAL_URL=${JUPYTER_SERVER_PUBLIC_URL}
 
  # Get current access token + preferred username
  response=$(curl -s -X "GET" -H "Authorization: token ${JUPYTERHUB_API_TOKEN}" -H "Accept: application/json" "${JUPYTERHUB_API_URL}/user_oauth")

  access_token=$(echo "$response" | jq -r '.auth_state.access_token')
  preferred_username=$(echo "$response" | jq -r '.auth_state.preferred_username')
  if [ "$preferred_username" = "null" ]; then
    unset preferred_username
  fi

  echo "$(date) - Set environment variables done" 
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

mount_just_home () {
  if [[ -n $preferred_username && -n $access_token ]]; then
    echo "$(date) - Mount HPC Home directories for ${preferred_username} ..."
    mkdir -p /p/home/jusers/${preferred_username}

    curl -sS -X POST http://localhost:8090/ -H "Accept: application/json" -H "Content-Type: application/json" -d '{"path": "just_homes", "options": {"displayName": "JUST ($HOME)", "template": "uftp", "external": "true", "readonly": "false", "config": { "remotepath": "/p/home/jusers/'"${preferred_username}"'", "type": "uftp", "auth_url": "https://uftp.fz-juelich.de/UFTP_Auth/rest/auth/JUDAC", "custompath": "", "access_token": "'"${access_token}"'"}}}'

    src_dir="/home/jovyan/data_mounts/just_homes"
    dest_dir="/p/home/jusers/$preferred_username"

    mkdir -p "$dest_dir"

    for sub in "$src_dir"/*; do
      [ -d "$sub" ] || continue  # skip non-directories
      ln -sfn "$sub" "$dest_dir/$(basename "$sub")"
    done

    ln -s /home/jovyan /p/home/jusers/${preferred_username}/jsccloud
    export HOME="/p/home/jusers/${preferred_username}/jsccloud"
    echo "$(date) - Mount HPC Home directories for ${preferred_username} done"
  fi
}

mount_just_project_dirs () {
  if [[ -n $preferred_username && -n $access_token ]]; then
    echo "$(date) - Mount HPC Project directories for ${preferred_username} ..."
    options=$(python3 /usr/local/bin/get_mount_projects.py https://login.jsc.fz-juelich.de/oauth2/userinfo $access_token)

    IFS=',' read -ra opts <<< "$options"
    for opt in "${opts[@]}"; do
        curl -sS -X POST http://localhost:8090/ -H "Accept: application/json" -H "Content-Type: application/json" -d '{"path": "just_project1_'"${opt}"'", "options": {"displayName": "JUST ($PROJECT '"${opt}"')", "template": "uftp", "external": "true", "readonly": "false", "config": { "remotepath": "/p/project1/'"${opt}"'", "type": "uftp", "group": "'"${opt}"'", "auth_url": "https://uftp.fz-juelich.de/UFTP_Auth/rest/auth/JUDAC", "custompath": "", "access_token": "'"${access_token}"'"}}}'
        ln -sfn /home/jovyan/data_mounts/just_project1_$opt /p/project1/$opt
        curl -sS -X POST http://localhost:8090/ -H "Accept: application/json" -H "Content-Type: application/json" -d '{"path": "just_scratch_'"${opt}"'", "options": {"displayName": "JUST ($SCRATCH '"${opt}"')", "template": "uftp", "external": "true", "readonly": "false", "config": { "remotepath": "/p/scratch/'"${opt}"'", "type": "uftp", "group": "'"${opt}"'", "auth_url": "https://uftp.fz-juelich.de/UFTP_Auth/rest/auth/JUDAC", "custompath": "", "access_token": "'"${access_token}"'"}}}'
        ln -sfn /home/jovyan/data_mounts/just_scratch_$opt /p/scratch/$opt
    done        
    export PROJECT="/p/project1"
    export SCRATCH="/p/scratch"
    echo "$(date) - Mount HPC Project directories for ${preferred_username} done"
  fi
}

mount_just_data () {
  if [[ -n $preferred_username && -n $access_token ]]; then
    echo "$(date) - Mount HPC Data directories for ${preferred_username} ..."
    curl -sS -X POST http://localhost:8090/ -H "Accept: application/json" -H "Content-Type: application/json" -d '{"path": "just_data1", "options": {"displayName": "JUST ($DATA)", "template": "uftp", "external": "true", "readonly": "false", "config": { "remotepath": "/p/data1", "type": "uftp", "auth_url": "https://uftp.fz-juelich.de/UFTP_Auth/rest/auth/JUDAC", "custompath": "", "access_token": "'"${access_token}"'"}}}'    
    ln -sfn /home/jovyan/data_mounts/just_data1 /p/data1
    export DATA="/p/data1"
    echo "$(date) - Mount HPC Data directories for ${preferred_username} done"
  fi
}

cleanup () {
  echo "$(date) - Start cleanup."
  # Send Cancel to JupyterHub, this way we can use restartPolicy: Always
  # to "survive" VM reboots, but do not always restart properly stopped
  # labs.
  curl -X "POST" -d '{"failed": true, "progress": 100, "html_message": "<details><summary>Cleanup successful.</summary>Post stop hook ran successful</details>"}' ${JUPYTERHUB_EVENTS_URL}
  echo "$(date) - Cleanup done."
}

update_config () {
  echo "" >> /usr/local/etc/jupyter/jupyter_server_config.py
  if [[ -f ${EBROOTJUPYTERLAB}/etc/jupyter/jupyter_notebook_config.py ]]; then
    echo "$(date) - Add system specific config ..."
    cat ${EBROOTJUPYTERLAB}/etc/jupyter/jupyter_notebook_config.py >> /usr/local/etc/jupyter/jupyter_server_config.py
    for path in ${JUPYTER_EXTRA_LABEXTENSIONS_PATH//:/$'\n'}; do
      echo "c.LabServerApp.extra_labextensions_path.append('$path')" >> /usr/local/etc/jupyter/jupyter_server_config.py
    done
    echo "$(date) - Add system specific config done"
  fi
  
  echo "c.ServerApp.root_dir = '/'" >> /usr/local/etc/jupyter/jupyter_server_config.py
  if [[ -n $preferred_username && -n $access_token ]]; then
    echo "c.ServerApp.default_url = '/lab/tree/p/home/jusers/${preferred_username}/jsccloud'" >> /usr/local/etc/jupyter/jupyter_server_config.py
  else
    echo "c.ServerApp.default_url = '/lab/tree/p/home/jovyan'" >> /usr/local/etc/jupyter/jupyter_server_config.py
  fi

  # update favorite-dirs with $HOME,$PROJECT,$SCRATCH,
  echo "$(date) - Update favorites ..."
  /usr/local/bin/update_favorites_json
  echo "$(date) - Update favorites done"
  
}

start () {
  echo "$(date) - Start ${JUPYTERJSC_USER_CMD} with args ${@} ..."
  ${JUPYTERJSC_USER_CMD} ${@} 2>&1 | tee ${JUPYTER_LOG_DIR}/stdout
  echo "$(date) - Start ${JUPYTERJSC_USER_CMD} done" 
}

requirements
set_env
load_modules
mount_just_home
mount_just_project_dirs
mount_just_data
update_config
start
cleanup
