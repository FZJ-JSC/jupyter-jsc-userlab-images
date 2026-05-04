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
  export CURL_ARGS="--silent --write-out %{http_code} --output /dev/null --no-keepalive --connect-timeout 5 --retry 3"
  export CURL_HEADERS="-H \"Authorization: token ${JUPYTERHUB_API_TOKEN}\" -H \"Content-Type: application/json\" -H \"Accept: application/json\""
 
  # Get current access token + preferred username
  response=$(curl -s -X "GET" -H "Authorization: token ${JUPYTERHUB_API_TOKEN}" -H "Accept: application/json" "${JUPYTERHUB_API_URL}/user_oauth")

  access_token=$(echo "$response" | jq -r '.auth_state.access_token')
  preferred_username=$(echo "$response" | jq -r '.auth_state.preferred_username')
  if [ "$preferred_username" = "null" ]; then
    unset preferred_username
  fi

  echo "$(date) - Set environment variables done" 
}

send_event () {
  BODY=${1//\'/}
  CURL_CMD="curl ${CURL_ARGS} ${CURL_HEADERS} -d '${BODY}' -X \"POST\" ${JUPYTERHUB_EVENTS_URL}"
  eval " $CURL_CMD"
}

send_spawn_update () {
  PROGRESS=$1
  SUMMARY=$2
  DETAILS=$3
  BODY="{\"progress\": ${PROGRESS}, \"failed\": false, \"html_message\": \"<details><summary>${SUMMARY}</summary>${DETAILS}</details>\"}"
  HTTPCODE=$(send_event "$BODY")
  if [[ ${HTTPCODE} -lt 200 || ${HTTPCODE} -gt 299 ]]; then
    echo "$(date) - Could not send status update (${HTTPCODE} - ${PROGRESS}%: ${SUMMARY} - ${DETAILS}). Cancel start."
    exit 1
  else
    echo "$(date) - Spawn update (${PROGRESS}%) successful: ${HTTPCODE}"
  fi
}

send_spawn_update_fail () {
  SUMMARY=$1
  DETAILS=$2
  BODY="{\"progress\": 100, \"failed\": true, \"html_message\": \"<details><summary>${SUMMARY}</summary>${DETAILS}</details>\"}"
  HTTPCODE=$(send_event "$BODY")
  if [[ ${HTTPCODE} -lt 200 || ${HTTPCODE} -gt 299 ]]; then
    echo "$(date) - Could not send status update (${HTTPCODE} - ${PROGRESS}%: ${SUMMARY} - ${DETAILS}). Cancel start."
    exit 1
  else
    echo "$(date) - Spawn update (${PROGRESS}%) successful: ${HTTPCODE}"
  fi
}

load_modules () {
  echo "$(date) - Load modules ..."
  send_spawn_update 90 "Load modules ..." "This may take a few seconds."

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
  send_spawn_update 91 "Load modules done" "Modules loaded successfully."
  echo "$(date) - Load modules done"
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
  if command -v ${JUPYTERJSC_USER_CMD} >/dev/null 2>&1; then
      echo "$(date) - Start ${JUPYTERJSC_USER_CMD} with args ${@} ..."
      send_spawn_update 95 "Start JupyterLab" "You will be redirected, when your JupyterLab is ready. This may take a few seconds. Logs are stored at ${JUPYTER_LOG_DIR}/stdout"
      ${JUPYTERJSC_USER_CMD} ${@} 2>&1 | tee ${JUPYTER_LOG_DIR}/stdout
      cleanup
      echo "$(date) - Start ${JUPYTERJSC_USER_CMD} done" 
  else
      echo "$(date) - ${JUPYTERJSC_USER_CMD} not available."
      send_spawn_update 95 "Could not start JupyterLab" "Could not find ${JUPYTERJSC_USER_CMD} executable."
      exit 1
  fi
}

requirements
set_env
load_modules
update_config
start
