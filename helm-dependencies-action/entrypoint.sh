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

function get_latest_artifacthub {
  # owner/repository
  local HELM_NAME=$1

  echo $(curl -sSL "https://artifacthub.io/api/v1/packages/helm/$HELM_NAME/feed/rss" | \
    yq -p=xml '.rss.channel.item[0].title')
}

##############################

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
  
  echo ${DEPENDENCIES} | while read ITEM; do
    local REPO_NAME=$(echo ${ITEM} | jq -r '.repository.name')
    get_latest_artifacthub ${REPO_NAME}
  done
}

echo "[+] helm-dependencies"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"

main

echo "[-] helm-dependencies"
