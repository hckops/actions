#!/bin/bash

set -euo pipefail

##############################

PARAM_GITOPS_SSH_KEY=${1:?"Missing GITOPS_SSH_KEY"}
PARAM_ARGOCD_ADMIN_PASSWORD=${2:?"Missing ARGOCD_ADMIN_PASSWORD"}
PARAM_KUBECONFIG=${3:?"Missing KUBECONFIG"}
PARAM_CHART_PATH=${4:?"Missing CHART_PATH"}
PARAM_VERSION=${5:-"HEAD"}

##############################

echo "[+] bootstrap"
echo "[*] GITOPS_SSH_KEY=${PARAM_GITOPS_SSH_KEY}"
echo "[*] ARGOCD_ADMIN_PASSWORD=${PARAM_ARGOCD_ADMIN_PASSWORD}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"
echo "[*] CHART_PATH=${PARAM_CHART_PATH}"
echo "[*] VERSION=${PARAM_VERSION}"

NAMESPACE="argocd"
CHART_NAME="argocd"

# add helm repository
helm repo add argo  "https://argoproj.github.io/argo-helm"

# manually apply "argocd-config" chart and "argocd" dependency with crds
helm template ${CHART_NAME} \
  --include-crds \
  --dependency-update \
  --namespace ${NAMESPACE} \
  --values "${PARAM_CHART_PATH}/values.yaml" \
  --values "${PARAM_CHART_PATH}/values-bootstrap.yaml" \
  --set repository.targetRevision=${PARAM_VERSION} \
  --set argocd.configs.secret.argocdServerAdminPassword="${PARAM_ARGOCD_ADMIN_PASSWORD}" \
  --set argocd.configs.credentialTemplates.ssh-creds.sshPrivateKey="${PARAM_GITOPS_SSH_KEY}" \
  ${PARAM_CHART_PATH} | kubectl --kubeconfig ${PARAM_KUBECONFIG} apply --namespace ${NAMESPACE} -f -

echo "[-] bootstrap"
