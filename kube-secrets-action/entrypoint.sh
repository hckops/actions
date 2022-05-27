#!/bin/bash

set -euo pipefail

##############################

PARAM_KUBECONFIG=${1:?"Missing KUBECONFIG"}
PARAM_PROVIDER=${2:?"Missing PROVIDER"}

##############################

# global param: <PARAM_KUBECONFIG>
# global param: <PARAM_PROVIDER>
function init_secret {
  local NAMESPACE="kube-secrets"

  # ORACLE
  local PARAM_ORACLE_PRIVATE_KEY=${3:?"Missing ORACLE_PRIVATE_KEY"}
  local PARAM_ORACLE_FINGERPRINT=${4:?"Missing FINGERPRINT"}
  echo "[-] ORACLE_PRIVATE_KEY=${PARAM_ORACLE_PRIVATE_KEY}"
  echo "[-] ORACLE_FINGERPRINT=${PARAM_ORACLE_FINGERPRINT}"

  helm template \
    --values chart/values.yaml \
    --set provider=${PARAM_PROVIDER} \
    --set externalSecrets.oracle.privateKey="${PARAM_ORACLE_PRIVATE_KEY}" \
    --set externalSecrets.oracle.fingerprint="${PARAM_ORACLE_FINGERPRINT}" \
    chart/ | kubectl --kubeconfig ${PARAM_KUBECONFIG} --namespace ${NAMESPACE} apply -f
}

##############################

echo "[+] kube-secrets"
echo "[*] PROVIDER=${PARAM_PROVIDER}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"

# TODO dry run: test-*.yaml prints only secret but do not apply
init_secret

echo "[-] kube-secrets"
