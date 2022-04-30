#!/bin/bash

set -euo pipefail

##############################

PARAM_GITHUB_TOKEN=${1:?"Missing GITHUB_TOKEN"}
PARAM_ACCESS_TOKEN=${2:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${3:?"Missing CONFIG_PATH"}
PARAM_ENABLED=${4:?"Missing ENABLED"}

##############################

# param #1 (optional): <string>
# global param: <PARAM_GITHUB_TOKEN>
# action param: <GITHUB_REPOSITORY>
# returns SHA
function fetch_commit_sha {
  # default latest (index 0)
  local COMMIT_INDEX=${1:-"0"}
  # fetch last 2 commits only
  local COMMITS_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/commits?per_page=2&page=1"

  # extract commit sha
  echo $(curl -sSL \
    -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    ${COMMITS_URL} | jq -r --arg COMMIT_INDEX "${COMMIT_INDEX}" '.[$COMMIT_INDEX|tonumber].sha')
}

# param #1: <string>
# param #2: <string>
# param #3: <string>
# global param: <PARAM_GITHUB_TOKEN>
# action param: <GITHUB_REPOSITORY>
function download_file {
  local FILE_PATH=$1
  local TMP_PATH=$2
  local COMMIT_REF=$3
  echo "[-] TMP_PATH=${TMP_PATH} | COMMIT_REF=${COMMIT_REF}"

  curl -sSL -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -o ${TMP_PATH} \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${FILE_PATH}?ref=${COMMIT_REF}"
}

# param #1: <string>
# param #2: <string>
# global param: <PARAM_ACCESS_TOKEN>
# action param: <GITHUB_REPOSITORY>
function doctl_cluster {
  local PARAM_ACTION=$1
  local CONFIG_PATH=$2
  local CLUSTER_NAME=$(yq e '.name' ${CONFIG_PATH})
  echo "[-] ACTION=${PARAM_ACTION}"
  echo "[-] CLUSTER_NAME=${CLUSTER_NAME}"

  case ${PARAM_ACTION} in
    "create")
      local CLUSTER_COUNT=$(yq e '.config.count' ${CONFIG_PATH})
      local CLUSTER_REGION=$(yq e '.config.region' ${CONFIG_PATH})
      local CLUSTER_SIZE=$(yq e '.config.size' ${CONFIG_PATH})
      echo "[-] CLUSTER_COUNT=${CLUSTER_COUNT}"
      echo "[-] CLUSTER_REGION=${CLUSTER_REGION}"
      echo "[-] CLUSTER_SIZE=${CLUSTER_SIZE}"

      doctl kubernetes cluster create ${CLUSTER_NAME} \
        --access-token ${PARAM_ACCESS_TOKEN} \
        --count ${CLUSTER_COUNT} \
        --region ${CLUSTER_REGION} \
        --size ${CLUSTER_SIZE} \
        --tag "repository:${GITHUB_REPOSITORY}" \
        --wait false
    ;;
    "delete")
      doctl kubernetes cluster delete ${CLUSTER_NAME} \
        --access-token ${PARAM_ACCESS_TOKEN} \
        --force
    ;;
    *)
      echo "ERROR: unknown command"
      exit 1
    ;;
  esac
}

##############################

echo "[+] kube-do"
# global
echo "[*] GITHUB_REPOSITORY=${GITHUB_REPOSITORY}"
# params
echo "[*] GITHUB_TOKEN=${PARAM_GITHUB_TOKEN}"
echo "[*] ACCESS_TOKEN=${PARAM_ACCESS_TOKEN}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] ENABLED=${PARAM_ENABLED}"

CURRENT_CONFIG_PATH="/tmp/current"
CURRENT_COMMIT=$(fetch_commit_sha)
PREVIOUS_CONFIG_PATH="/tmp/previous"
PREVIOUS_COMMIT=$(fetch_commit_sha 1)

# download config revisions for comparison
download_file ${PARAM_CONFIG_PATH} ${CURRENT_CONFIG_PATH} ${CURRENT_COMMIT}
download_file ${PARAM_CONFIG_PATH} ${PREVIOUS_CONFIG_PATH} ${PREVIOUS_COMMIT}

CURRENT_STATUS=$(yq e '.status' ${CURRENT_CONFIG_PATH})
PREVIOUS_STATUS=$(yq e '.status' ${PREVIOUS_CONFIG_PATH})

if [[ ${PARAM_ENABLED} == "true" ]]; then
  echo "[*] Action enabled"

  if [[ ${CURRENT_STATUS} == ${PREVIOUS_STATUS} ]]; then
    # TODO check real status of the cluster
    echo "[*] Cluster is already ${CURRENT_STATUS}"
  else
    echo "[*] Update cluster status to ${CURRENT_STATUS}"

    [[ ${CURRENT_STATUS} == "UP" ]] && \
      doctl_cluster "create" ${CURRENT_CONFIG_PATH}

    [[ ${CURRENT_STATUS} == "DOWN" ]] && \
      doctl_cluster "delete" ${CURRENT_CONFIG_PATH}
  fi

  echo "::set-output name=status::${CURRENT_STATUS}"
else
  echo "[*] Action disabled"
  echo "::set-output name=status::${PREVIOUS_STATUS}"
fi

echo "[-] kube-do"
