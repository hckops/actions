#!/bin/bash

# https://www.mulle-kybernetik.com/modern-bash-scripting/state-euxo-pipefail.html
set -euo pipefail

CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
ROOT_PATH="${CURRENT_PATH}/.."
cd ${CURRENT_PATH}

##############################

PARAM_ACTION=${1:?"Missing ACTION"}
PARAM_KUBE=${2:-"template"}

# https://www.devglan.com/online-tools/bcrypt-hash-generator
# https://www.browserling.com/tools/bcrypt
# admin|argocd
ARGOCD_ADMIN_PASSWORD='$2a$04$qj3hWU1Id.l.4e/8JN4Kr.ecQDuf3hhyG0TbsLeDcZV2kRG/AizY2'
MINIKUBE_CONFIG="${HOME}/.kube/config"
CHART_PATH="${ROOT_PATH}/../kube-${PARAM_KUBE}/charts/argocd-config"
CONFIG_PATH="INVALID_CONFIG_PATH"

##############################

echo "[+] local"
echo "[*] ACTION=${PARAM_ACTION}"
echo "[*] KUBE=${PARAM_KUBE}"
echo "[*] CHART_PATH=${CHART_PATH}"

case ${PARAM_ACTION} in
  "bootstrap")
    ../bootstrap-action/entrypoint.sh \
      "$(cat "${HOME}/.ssh/id_ed25519_gitops")" \
      ${ARGOCD_ADMIN_PASSWORD} \
      ${MINIKUBE_CONFIG} \
      ${CHART_PATH} \
      ${CONFIG_PATH}
  ;;
  *)
    echo "ERROR: unknown command"
    exit 1
  ;;
esac

echo "[-] local"
