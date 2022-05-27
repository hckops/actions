#!/bin/bash

set -euo pipefail

##############################

PARAM_KUBECONFIG=${1:?"Missing KUBECONFIG"}
PARAM_OPERATOR=${2:?"Missing OPERATOR"}
# LASTPASS
PARAM_LASTPASS_USERNAME=${3:?"Missing LASTPASS_USERNAME"}
PARAM_LASTPASS_PASSWORD=${4:?"Missing LASTPASS_PASSWORD"}
# ORACLE
PARAM_ORACLE_PRIVATE_KEY=${5:?"Missing ORACLE_PRIVATE_KEY"}
PARAM_ORACLE_FINGERPRINT=${6:?"Missing ORACLE_FINGERPRINT"}


##############################

# global param: <PARAM_KUBECONFIG>
# global param: <PARAM_OPERATOR>
function init_secret {
  local NAMESPACE="kube-secrets"

  helm template \
    --values chart/values.yaml \
    --set operator=${PARAM_OPERATOR} \
    --set edgelevel.lastpass.username="${PARAM_LASTPASS_USERNAME}" \
    --set edgelevel.lastpass.password="${PARAM_LASTPASS_PASSWORD}" \
    --set externalSecrets.oracle.privateKey="${PARAM_ORACLE_PRIVATE_KEY}" \
    --set externalSecrets.oracle.fingerprint="${PARAM_ORACLE_FINGERPRINT}" \
    chart/ | kubectl --kubeconfig ${PARAM_KUBECONFIG} --namespace ${NAMESPACE} apply -f
}

##############################

echo "[+] kube-secrets"
echo "[*] OPERATOR=${PARAM_OPERATOR}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"
# LASTPASS
echo "[-] LASTPASS_USERNAME=${PARAM_LASTPASS_USERNAME}"
echo "[-] LASTPASS_PASSWORD=${PARAM_LASTPASS_PASSWORD}"
# ORACLE
echo "[-] ORACLE_PRIVATE_KEY=${PARAM_ORACLE_PRIVATE_KEY}"
echo "[-] ORACLE_FINGERPRINT=${PARAM_ORACLE_FINGERPRINT}"

# TODO dry run in ci: "test-kube-secrets.yml" should only print "helm template"
init_secret

echo "[-] kube-secrets"
