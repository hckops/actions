#!/bin/bash

set -euo pipefail

##############################

PARAM_GITHUB_TOKEN=${1:?"Missing GITHUB_TOKEN"}
PARAM_ACCESS_TOKEN=${2:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${3:?"Missing CONFIG_PATH"}
PARAM_ENABLED=${4:?"Missing ENABLED"}
PARAM_WAIT=${5:?"Missing WAIT"}
PARAM_SKIP=${6:?"Missing SKIP"}

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
# global param: <PARAM_WAIT>
# action param: <GITHUB_REPOSITORY>
function doctl_cluster {
  local PARAM_ACTION=$1
  local CONFIG_PATH=$2
  local CLUSTER_NAME=$(yq e '.name' ${CONFIG_PATH})
  local REPOSITORY_NAME=$(echo $GITHUB_REPOSITORY | sed 's|/|-|g')
  echo "[-] DOCTL_ACTION=${PARAM_ACTION}"
  echo "[-] CLUSTER_NAME=${CLUSTER_NAME}"

  case ${PARAM_ACTION} in
    "create")
      local CLUSTER_COUNT=$(yq e '.config.count' ${CONFIG_PATH})
      local CLUSTER_REGION=$(yq e '.config.region' ${CONFIG_PATH})
      local CLUSTER_SIZE=$(yq e '.config.size' ${CONFIG_PATH})
      local CLUSTER_TAGS="repository:${REPOSITORY_NAME}"
      echo "[-] CLUSTER_COUNT=${CLUSTER_COUNT}"
      echo "[-] CLUSTER_REGION=${CLUSTER_REGION}"
      echo "[-] CLUSTER_SIZE=${CLUSTER_SIZE}"
      echo "[-] CLUSTER_TAGS=${CLUSTER_TAGS}"

      doctl kubernetes cluster create ${CLUSTER_NAME} \
        --access-token ${PARAM_ACCESS_TOKEN} \
        --count ${CLUSTER_COUNT} \
        --region ${CLUSTER_REGION} \
        --size ${CLUSTER_SIZE} \
        --tag ${CLUSTER_TAGS} \
        --wait=${PARAM_WAIT}
    ;;
    "config")
      local KUBE_CONFIG="${REPOSITORY_NAME}-kubeconfig.yaml"
      echo "[-] KUBE_CONFIG=${KUBE_CONFIG}"

      # save it in the root directory
      doctl kubernetes cluster kubeconfig show ${CLUSTER_NAME} \
        --access-token ${PARAM_ACCESS_TOKEN} > ${KUBE_CONFIG}
      
      # returns kubeconfig path
      echo "::set-output name=kubeconfig::${KUBE_CONFIG}"
    ;;
    "delete")
      local CLUSTER_DOMAIN=$(yq e '.config.domain.name // "INVALID_DOMAIN"' ${CONFIG_PATH})
      echo "[-] CLUSTER_DOMAIN=${CLUSTER_DOMAIN}"

      doctl kubernetes cluster delete ${CLUSTER_NAME} \
        --access-token ${PARAM_ACCESS_TOKEN} \
        --force

      if [[ ${CLUSTER_DOMAIN} != "INVALID_DOMAIN" ]]; then
        # wait 60 seconds at least before deleting the domain
        # or external-dns will keep updading dns records when the domain is re-added
        sleep 60
        # removes domain records and the associated load balancer
        doctl_reset_networking ${CLUSTER_DOMAIN}
      fi
    ;;
    *)
      echo "ERROR: unknown command"
      exit 1
    ;;
  esac
}

# param #1: <string>
# global param: <PARAM_ACCESS_TOKEN>
function doctl_reset_networking {
  local DOMAIN_NAME=$1
  # matches also invalid ip
  local REGEX_IP="([0-9]{1,3}[\.]){3}[0-9]{1,3}"

  # returns load balancer ip associated to this domain
  local LOAD_BALANCER_IP=$(doctl compute domain records list ${DOMAIN_NAME} \
    --access-token ${PARAM_ACCESS_TOKEN} | \
      grep -E -o ${REGEX_IP} | \
      uniq -d)

  # returns load balancer id
  local LOAD_BALANCER_ID=$(doctl compute load-balancer list \
    --access-token ${PARAM_ACCESS_TOKEN} \
    --format=IP,ID --no-header | \
      grep ${LOAD_BALANCER_IP} | \
      awk '{print $2}')

  echo "[-] LOAD_BALANCER_IP=${LOAD_BALANCER_IP}"
  echo "[-] LOAD_BALANCER_ID=${LOAD_BALANCER_ID}"

  # deletes load balancer
  doctl compute load-balancer delete ${LOAD_BALANCER_ID} \
    --access-token ${PARAM_ACCESS_TOKEN} \
    --force

  # deletes domain records
  doctl compute domain delete ${DOMAIN_NAME} \
    --access-token ${PARAM_ACCESS_TOKEN} \
    --force

  # adds domain back immediately:
  # it should be added only when the cluster is created,
  # but there are bots that keep trying to steal other users domains,
  # and the only way to claim it back is to open a support ticket showing proof of ownership.
  # DigitalOcean is not a registrar and they can't verify it automatically
  doctl compute domain create ${DOMAIN_NAME} \
    --access-token ${PARAM_ACCESS_TOKEN}
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
echo "[*] WAIT=${PARAM_WAIT}"
echo "[*] SKIP=${PARAM_SKIP}"

CURRENT_CONFIG_PATH="/tmp/current"
CURRENT_COMMIT=$(fetch_commit_sha)
PREVIOUS_CONFIG_PATH="/tmp/previous"
PREVIOUS_COMMIT=$(fetch_commit_sha 1)

# download config revisions for comparison
download_file ${PARAM_CONFIG_PATH} ${CURRENT_CONFIG_PATH} ${CURRENT_COMMIT}
download_file ${PARAM_CONFIG_PATH} ${PREVIOUS_CONFIG_PATH} ${PREVIOUS_COMMIT}

CURRENT_STATUS=$(yq e '.status' ${CURRENT_CONFIG_PATH})
PREVIOUS_STATUS=$(yq e '.status' ${PREVIOUS_CONFIG_PATH})
echo "[-] CURRENT_STATUS=${CURRENT_STATUS} | PREVIOUS_STATUS=${PREVIOUS_STATUS}"

if [[ ${PARAM_ENABLED} == "true" ]]; then
  echo "[*] Action enabled"

  if [[ ${CURRENT_STATUS} == "UP" && ${PARAM_SKIP} == "true" ]]; then
    # init kubeconfig only
    doctl_cluster "config" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::CREATE"

  # TODO should check cluster real status
  elif [[ ${CURRENT_STATUS} == ${PREVIOUS_STATUS} ]]; then
    # do nothing
    echo "[*] Cluster is already ${CURRENT_STATUS}"
    # returns UP or DOWN
    echo "::set-output name=status::${CURRENT_STATUS}"

  elif [[ ${CURRENT_STATUS} == "UP" ]]; then
    # create cluster and init kubeconfig
    doctl_cluster "create" ${CURRENT_CONFIG_PATH}
    doctl_cluster "config" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::CREATE"

  elif [[ ${CURRENT_STATUS} == "DOWN" ]]; then
    # delete cluster
    doctl_cluster "delete" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::DELETE"
  fi
else
  echo "[*] Action disabled"
  # returns UP or DOWN
  echo "::set-output name=status::${PREVIOUS_STATUS}"
fi

echo "[-] kube-do"
