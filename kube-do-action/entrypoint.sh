#!/bin/bash

set -euo pipefail

##############################

PARAM_GITHUB_TOKEN=${1:?"Missing GITHUB_TOKEN"}
PARAM_ACCESS_TOKEN=${2:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${3:?"Missing CONFIG_PATH"}
PARAM_CONFIG_REVISION=${4:-"HEAD"}
PARAM_ENABLED=${5:?"Missing ENABLED"}
PARAM_WAIT=${6:?"Missing WAIT"}
PARAM_SKIP_CREATE=${7:?"Missing SKIP_CREATE"}

CONFIG_VERSION_SUPPORTED="1"

##############################

# param #1: <string>
# param #2: <string> (optional)
# global param: <PARAM_GITHUB_TOKEN>
# global param: <PARAM_CONFIG_REVISION>
# action param: <GITHUB_REPOSITORY>
# returns SHA
function fetch_commit_sha {
  # default latest (index 0)
  local COMMIT_INDEX=${1:-"0"}
  # fetch last 2 commits only
  local COMMITS_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/commits?sha=${PARAM_CONFIG_REVISION}&per_page=2&page=1"

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
function get_config {
  local CONFIG_PATH=$1
  local JQ_PATH=$2

  # JQ_PATH must be escaped due to "default" issue
  echo $(yq -o=json '.' "${CONFIG_PATH}" | jq -r "${JQ_PATH}")
}

# TODO [json|yaml]-schema validation: https://asdf-standard.readthedocs.io/en/1.5.0/schemas.html
# param #1: <string>
# global param: <CONFIG_VERSION_SUPPORTED>
function validate_config {
  local CONFIG_PATH=$1

  echo "[*] Validate config: ${CONFIG_PATH}"
  # debug
  yq -o=json '.' ${CONFIG_PATH}
  
  local CONFIG_VERSION=$(get_config ${CONFIG_PATH} '.version')
  local CONFIG_PROVIDER=$(get_config ${CONFIG_PATH} '.provider')
  local CONFIG_STATUS=$(get_config ${CONFIG_PATH} '.status')

  if [[ ${CONFIG_VERSION} != ${CONFIG_VERSION_SUPPORTED} ]]; then
    echo "[*] Invalid version: ${CONFIG_VERSION}"
    echo "::set-output name=status::ERROR"
    exit 1

  elif [[ ${CONFIG_PROVIDER} != "digitalocean" ]]; then
    echo "[*] Invalid provider: ${CONFIG_PROVIDER}"
    echo "::set-output name=status::ERROR"
    exit 1

  elif [[ ${CONFIG_STATUS} != "UP" && ${CONFIG_STATUS} != "DOWN" ]]; then
    echo "[*] Invalid status: ${CONFIG_STATUS}"
    echo "::set-output name=status::ERROR"
    exit 1
  fi
}

# param #1: <string>
# param #2: <string>
# global param: <PARAM_ACCESS_TOKEN>
# global param: <PARAM_WAIT>
# action param: <GITHUB_REPOSITORY>
function doctl_cluster {
  local PARAM_ACTION=$1
  local CONFIG_PATH=$2
  local CLUSTER_NAME=$(get_config ${CONFIG_PATH} '.name')
  local REPOSITORY_NAME=$(echo $GITHUB_REPOSITORY | sed 's|/|-|g')
  echo "[-] DOCTL_CLUSTER_ACTION=${PARAM_ACTION}"
  echo "[-] CLUSTER_NAME=${CLUSTER_NAME}"

  case ${PARAM_ACTION} in
    "create")
      local CLUSTER_COUNT=$(get_config ${CONFIG_PATH} '.digitalocean.cluster.count')
      local CLUSTER_REGION=$(get_config ${CONFIG_PATH} '.digitalocean.cluster.region')
      local CLUSTER_SIZE=$(get_config ${CONFIG_PATH} '.digitalocean.cluster.size')
      local CLUSTER_TAGS="repository:${REPOSITORY_NAME}"
      echo "[-] CLUSTER_COUNT=${CLUSTER_COUNT}"
      echo "[-] CLUSTER_REGION=${CLUSTER_REGION}"
      echo "[-] CLUSTER_SIZE=${CLUSTER_SIZE}"
      echo "[-] CLUSTER_TAGS=${CLUSTER_TAGS}"

      # TODO --version
      # https://docs.digitalocean.com/reference/doctl/reference/kubernetes/cluster/create/
      # https://docs.digitalocean.com/reference/api/api-reference/#operation/kubernetes_create_cluster
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

# Domains MUST always be removed and added back immediately:
# they should be added only when the cluster is created and viceversa,
# but there are bots that keep trying to steal other users domains.
# If a domain is stolen, the only way to claim it back is to open a support ticket and show proof of ownership.
# DigitalOcean is not a registrar and they can't verify it automatically.
function doctl_domain_reset {
  local DOMAIN_NAME=$1
  echo "[*] Reset domain ${DOMAIN_NAME}"

  # deletes domain records
  doctl compute domain delete ${DOMAIN_NAME} \
    --access-token ${PARAM_ACCESS_TOKEN} \
    --force

  doctl compute domain create ${DOMAIN_NAME} \
    --access-token ${PARAM_ACCESS_TOKEN}
}

# param #1: <string>
# global param: <PARAM_ACCESS_TOKEN>
function doctl_load_balancer_delete {
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

  # TODO LOAD_BALANCER_ID is empty sometimes???

  # deletes load balancer
  doctl compute load-balancer delete ${LOAD_BALANCER_ID} \
    --access-token ${PARAM_ACCESS_TOKEN} \
    --force
}

# param #1: <string>
# param #2: <string>
# global param: <PARAM_ACCESS_TOKEN>
function doctl_network {
  local PARAM_ACTION=$1
  local CONFIG_PATH=$2
  local NETWORK_DOMAIN_MANAGED=$(get_config ${CONFIG_PATH} '.digitalocean.network.domain.managed // "false"')
  local NETWORK_DOMAIN_NAME=$(get_config ${CONFIG_PATH} '.digitalocean.network.domain.name // "INVALID_DOMAIN"')
  local NETWORK_LOAD_BALANCER_MANAGED=$(get_config ${CONFIG_PATH} '.digitalocean.network.loadBalancer.managed // "false"')

  echo "[-] DOCTL_NETWORK_ACTION=${PARAM_ACTION}"
  echo "[-] NETWORK_DOMAIN_MANAGED=${NETWORK_DOMAIN_MANAGED}"
  echo "[-] NETWORK_DOMAIN_NAME=${NETWORK_DOMAIN_NAME}"
  echo "[-] NETWORK_LOAD_BALANCER_MANAGED=${NETWORK_LOAD_BALANCER_MANAGED}"

  case ${PARAM_ACTION} in
    "init")
      if [[ ${NETWORK_DOMAIN_MANAGED} == "true" ]]; then
        echo "[*] Setup domain"
        doctl_domain_reset ${NETWORK_DOMAIN_NAME}
      else
        echo "[*] Domain setup skipped"
      fi
    ;;
    "reset")
      # removes domain records and the associated load balancer
      if [[ ${NETWORK_LOAD_BALANCER_MANAGED} == "true" && ${NETWORK_DOMAIN_NAME} != "INVALID_DOMAIN" ]]; then
        echo "[*] Cleanup LoadBalancer"
        doctl_load_balancer_delete ${NETWORK_DOMAIN_NAME}

        if [[ ${NETWORK_DOMAIN_MANAGED} == "true" ]]; then
          echo "[*] Cleanup domain"

          # wait before deleting the domain or external-dns will keep updading dns records when the domain is re-added
          echo "[*] sleeping 2 minutes..."
          sleep 2m

          doctl_domain_reset ${NETWORK_DOMAIN_NAME}
        else
          echo "[*] Domain cleanup skipped"
        fi
      else
        echo "[*] LoadBalancer cleanup skipped"
      fi
    ;;
    *)
      echo "ERROR: unknown command"
      exit 1
    ;;
  esac
}

# starts|stops the cluster based on the current "status"
function provision_cluster {
  local CURRENT_CONFIG_PATH="/tmp/current"
  local CURRENT_COMMIT=$(fetch_commit_sha)
  local PREVIOUS_CONFIG_PATH="/tmp/previous"
  local PREVIOUS_COMMIT=$(fetch_commit_sha 1)

  # download config revisions for comparison
  download_file ${PARAM_CONFIG_PATH} ${CURRENT_CONFIG_PATH} ${CURRENT_COMMIT}
  download_file ${PARAM_CONFIG_PATH} ${PREVIOUS_CONFIG_PATH} ${PREVIOUS_COMMIT}

  # validate current config
  validate_config ${CURRENT_CONFIG_PATH}

  local CURRENT_STATUS=$(get_config ${CURRENT_CONFIG_PATH} '.status')
  local PREVIOUS_STATUS=$(get_config ${PREVIOUS_CONFIG_PATH} '.status')
  echo "[-] CURRENT_STATUS=${CURRENT_STATUS} | PREVIOUS_STATUS=${PREVIOUS_STATUS}"

  # for development only: flag used to skip cluster creation
  if [[ ${CURRENT_STATUS} == "UP" && ${PARAM_SKIP_CREATE} == "true" ]]; then
    # init kubeconfig only
    doctl_cluster "config" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::CREATE"

  # TODO it should also check cluster real status
  elif [[ ${CURRENT_STATUS} == ${PREVIOUS_STATUS} ]]; then
    # do nothing
    echo "[*] Cluster is already ${CURRENT_STATUS}"
    # returns UP or DOWN
    echo "::set-output name=status::${CURRENT_STATUS}"

  elif [[ ${CURRENT_STATUS} == "UP" ]]; then
    # setup network
    doctl_network "init" ${CURRENT_CONFIG_PATH}
    # create cluster and init kubeconfig
    doctl_cluster "create" ${CURRENT_CONFIG_PATH}
    doctl_cluster "config" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::CREATE"

  elif [[ ${CURRENT_STATUS} == "DOWN" ]]; then
    # delete cluster
    doctl_cluster "delete" ${CURRENT_CONFIG_PATH}
    # cleanup network
    doctl_network "reset" ${CURRENT_CONFIG_PATH}
    echo "::set-output name=status::DELETE"
  fi
}

# function definition must be placed before any calls to the function
function main {
  if [[ ${PARAM_ENABLED} == "true" ]]; then
    echo "[*] Action enabled"
    provision_cluster
  else
    echo "[*] Action disabled"
    echo "::set-output name=status::DISABLE"
  fi
}

##############################

echo "[+] kube-do"
# global
echo "[*] GITHUB_REPOSITORY=${GITHUB_REPOSITORY}"
# params
echo "[*] GITHUB_TOKEN=${PARAM_GITHUB_TOKEN}"
echo "[*] ACCESS_TOKEN=${PARAM_ACCESS_TOKEN}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] CONFIG_REVISION=${PARAM_CONFIG_REVISION}"
echo "[*] ENABLED=${PARAM_ENABLED}"
echo "[*] WAIT=${PARAM_WAIT}"
echo "[*] SKIP_CREATE=${PARAM_SKIP_CREATE}"
echo "[*] CONFIG_VERSION_SUPPORTED=${CONFIG_VERSION_SUPPORTED}"

main

echo "[-] kube-do"
