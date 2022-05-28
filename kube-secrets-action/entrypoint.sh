#!/bin/bash

set -euo pipefail

##############################

PARAM_KUBECONFIG=${1:?"Missing KUBECONFIG"}
PARAM_ENABLED=${2:?"Missing ENABLED"}
PARAM_OPERATOR=${3:?"Missing OPERATOR"}
# LASTPASS
PARAM_LASTPASS_USERNAME=${4:?"Missing LASTPASS_USERNAME"}
PARAM_LASTPASS_PASSWORD=${5:?"Missing LASTPASS_PASSWORD"}
# AKEYLESS
PARAM_AKEYLESS_ACCESS_ID=${6:?"Missing AKEYLESS_ACCESS_ID"}
PARAM_AKEYLESS_ACCESS_TYPE=${7:?"Missing AKEYLESS_ACCESS_TYPE"}
PARAM_AKEYLESS_ACCESS_TYPE_PARAM=${8:?"Missing AKEYLESS_ACCESS_TYPE_PARAM"}
# ORACLE
PARAM_ORACLE_PRIVATE_KEY=${9:?"Missing ORACLE_PRIVATE_KEY"}
PARAM_ORACLE_FINGERPRINT=${10:?"Missing ORACLE_FINGERPRINT"}

##############################

# global param: <PARAM_KUBECONFIG>
# global param: <PARAM_ENABLED>
# global param: <PARAM_OPERATOR>
function init_secret {
  # default namespace
  local NAMESPACE="kube-secrets"
  # chart is in the root path
  local CHART_PATH="/chart"
  local OUTPUT_TEMPLATE="install.yaml"

  helm template \
    --values "${CHART_PATH}/values.yaml" \
    --set createNamespace="true" \
    --set operator="${PARAM_OPERATOR}" \
    --set edgelevel.lastpass.username="${PARAM_LASTPASS_USERNAME}" \
    --set edgelevel.lastpass.password="${PARAM_LASTPASS_PASSWORD}" \
    --set externalSecrets.akeyless.accessId="${PARAM_AKEYLESS_ACCESS_ID}" \
    --set externalSecrets.akeyless.accessType="${PARAM_AKEYLESS_ACCESS_TYPE}" \
    --set externalSecrets.akeyless.accessTypeParam="${PARAM_AKEYLESS_ACCESS_TYPE_PARAM}" \
    --set externalSecrets.oracle.privateKey="${PARAM_ORACLE_PRIVATE_KEY}" \
    --set externalSecrets.oracle.fingerprint="${PARAM_ORACLE_FINGERPRINT}" \
    ${CHART_PATH} > "${CHART_PATH}/${OUTPUT_TEMPLATE}"

    if [[ ${PARAM_ENABLED} == "true" ]]; then
      echo "[*] Action enabled"
      kubectl --kubeconfig ${PARAM_KUBECONFIG} --namespace ${NAMESPACE} apply -f "${CHART_PATH}/${OUTPUT_TEMPLATE}"
    else
      echo "[*] Action disabled"
      # debug
      #cat "${CHART_PATH}/${OUTPUT_TEMPLATE}"
    fi
}

##############################

echo "[+] kube-secrets"
echo "[*] OPERATOR=${PARAM_OPERATOR}"
echo "[*] ENABLED=${PARAM_ENABLED}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"
# LASTPASS
echo "[-] LASTPASS_USERNAME=${PARAM_LASTPASS_USERNAME}"
echo "[-] LASTPASS_PASSWORD=${PARAM_LASTPASS_PASSWORD}"
# AKEYLESS
echo "[-] AKEYLESS_ACCESS_ID=${PARAM_AKEYLESS_ACCESS_ID}"
echo "[-] AKEYLESS_ACCESS_TYPE=${PARAM_AKEYLESS_ACCESS_TYPE}"
echo "[-] AKEYLESS_ACCESS_TYPE_PARAM=${PARAM_AKEYLESS_ACCESS_TYPE_PARAM}"
# ORACLE
echo "[-] ORACLE_PRIVATE_KEY=${PARAM_ORACLE_PRIVATE_KEY}"
echo "[-] ORACLE_FINGERPRINT=${PARAM_ORACLE_FINGERPRINT}"

init_secret

echo "[-] kube-secrets"
