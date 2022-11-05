#!/bin/bash

set -euo pipefail

##############################

PARAM_CONFIG_PATH=${1:?"Missing CONFIG_PATH"}

##############################

# param #1: <string>
# param #2: <string>
function get_config {
  local CONFIG_PATH=$1
  local JQ_PATH=$2

  echo $(yq -o=json '.' "${CONFIG_PATH}" | jq -r "${JQ_PATH}")
}

# param #1: <string>
function get_latest_artifacthub {
  # owner/repository
  local HELM_NAME=$1

  # fetches latest version from rss feed (xml format)
  echo $(curl -sSL "https://artifacthub.io/api/v1/packages/helm/$HELM_NAME/feed/rss" | \
    yq -p=xml '.rss.channel.item[0].title')
}

# param #1: <string>
function update_dependency {
  local DEPENDENCY_JSON=$1
  local REPO_TYPE=$(echo ${DEPENDENCY_JSON} | jq -r '.repository.type')

  # debug
  echo ${DEPENDENCY_JSON} | jq '.'

  case ${REPO_TYPE} in
    "artifacthub")
      local REPO_NAME=$(echo ${DEPENDENCY_JSON} | jq -r '.repository.name')
      
      local SOURCE_FILE=$(echo ${DEPENDENCY_JSON} | jq -r '.source.file')
      local SOURCE_PATH=$(echo ${DEPENDENCY_JSON} | jq -r '.source.path')
      local CURRENT_VERSION=$(get_config ${SOURCE_FILE} ${SOURCE_PATH})
      local LATEST_VERSION=$(get_latest_artifacthub ${REPO_NAME})

      echo "[${REPO_NAME}] CURRENT=[${CURRENT_VERSION}] LATEST=[${LATEST_VERSION}]"
    ;;
    *)
      echo "ERROR: invalid repository type"
      exit 1
    ;;
  esac
}

##############################

# helm create examples/test-chart
# https://artifacthub.io/api/v1/packages/helm/datawire/emissary-ingress/feed/rss
# https://artifacthub.io/api/v1/packages/helm/argo/argo-events/feed/rss
# https://artifacthub.io/api/v1/packages/helm/argo/argo-workflows/feed/rss
# https://artifacthub.io/api/v1/packages/helm/cert-manager/cert-manager/feed/rss
# https://artifacthub.io/api/v1/packages/helm/bitnami/external-dns/feed/rss
# https://artifacthub.io/api/v1/packages/helm/external-secrets-operator/external-secrets/feed/rss
# https://artifacthub.io/api/v1/packages/helm/k8s-dashboard/kubernetes-dashboard/feed/rss
# https://artifacthub.io/api/v1/packages/helm/grafana/loki-stack/feed/rss
# https://artifacthub.io/api/v1/packages/helm/prometheus-community/kube-prometheus-stack/feed/rss

function main {
  local DEPENDENCIES=$(get_config ${PARAM_CONFIG_PATH} '.dependencies[]')
  
  # use the compact output option (-c) so each result is put on a single line and is treated as one item in the loop
  echo ${DEPENDENCIES} | jq -c '.' | while read ITEM; do
    update_dependency "${ITEM}"
  done
}

echo "[+] helm-dependencies"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"

main

echo "[-] helm-dependencies"
