#!/bin/bash

# https://www.mulle-kybernetik.com/modern-bash-scripting/state-euxo-pipefail.html
set -euo pipefail

CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
ROOT_PATH="${CURRENT_PATH}/.."
cd ${CURRENT_PATH}

##############################

PARAM_ACTION=${1:?"Missing ACTION"}

# admin|argocd
ARGOCD_ADMIN_PASSWORD='$2a$04$qj3hWU1Id.l.4e/8JN4Kr.ecQDuf3hhyG0TbsLeDcZV2kRG/AizY2'
MINIKUBE_CONFIG="${HOME}/.kube/config"
CHART_PATH="${ROOT_PATH}/../kube-template/charts/argocd-config"

##############################

echo "[+] local"
echo "[*] ACTION=${PARAM_ACTION}"

case ${PARAM_ACTION} in
  "bootstrap")
    ../bootstrap-action/entrypoint.sh \
      "$(cat "${HOME}/.ssh/id_ed25519_gitops")" \
      ${ARGOCD_ADMIN_PASSWORD} \
      ${MINIKUBE_CONFIG} \
      ${CHART_PATH}
  ;;
  *)
    echo "ERROR: unknown command"
    exit 1
  ;;
esac

echo "[-] local"
