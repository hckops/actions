#!/bin/bash

set -euo pipefail

##############################

PARAM_KUBECONFIG=${1:?"Missing KUBECONFIG"}

##############################

echo "[+] bootstrap"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"

# TODO
pwd
ls -la
helm version
kubectl --kubeconfig ${PARAM_KUBECONFIG} get nodes

echo "[-] bootstrap"
