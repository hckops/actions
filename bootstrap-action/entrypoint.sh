#!/bin/bash

set -euo pipefail

##############################

PARAM_GITOPS_SSH_KEY=${1:?"Missing GITOPS_SSH_KEY"}
PARAM_ARGOCD_ADMIN_PASSWORD=${2:?"Missing ARGOCD_ADMIN_PASSWORD"}
PARAM_KUBECONFIG=${3:?"Missing KUBECONFIG"}
# TODO CONFIG_PATH should be optional
PARAM_CONFIG_PATH=${4:?"Missing CONFIG_PATH"}
PARAM_CHART_PATH=${5:?"Missing CHART_PATH"}
PARAM_VERSION=${6:-"HEAD"}

##############################

# param #1: <string>
function get_config {
  local JQ_PATH=$1

  echo $(yq -o=json '.' "${PARAM_CONFIG_PATH}" | jq -r "${JQ_PATH}")
}

function bootstrap {
  local CHART_NAME="argocd"
  local NAMESPACE=$(get_config ${PARAM_CONFIG_PATH} '.bootstrap.namespace // "argocd"')
  # if the file doesn't exist apply twice the default values
  local VALUE_FILE_OVERRIDE=$(get_config ${PARAM_CONFIG_PATH} '.bootstrap.helmValueFile // "values.yaml"')

  # manually apply "argocd-config" chart and "argocd" dependency with crds
  helm template ${CHART_NAME} \
    --include-crds \
    --dependency-update \
    --namespace ${NAMESPACE} \
    --values "${PARAM_CHART_PATH}/values.yaml" \
    --values "${PARAM_CHART_PATH}/${VALUE_FILE_OVERRIDE}" \
    --values "${PARAM_CHART_PATH}/values-bootstrap.yaml" \
    --set repository.targetRevision=${PARAM_VERSION} \
    --set argocd.configs.secret.argocdServerAdminPassword="${PARAM_ARGOCD_ADMIN_PASSWORD}" \
    --set argocd.configs.credentialTemplates.ssh-creds.sshPrivateKey="${PARAM_GITOPS_SSH_KEY}" \
    ${PARAM_CHART_PATH} | kubectl --kubeconfig ${PARAM_KUBECONFIG} --namespace ${NAMESPACE} apply -f -
}

##############################

echo "[+] bootstrap"
echo "[*] GITOPS_SSH_KEY=${PARAM_GITOPS_SSH_KEY}"
echo "[*] ARGOCD_ADMIN_PASSWORD=${PARAM_ARGOCD_ADMIN_PASSWORD}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"
echo "[*] CHART_PATH=${PARAM_CHART_PATH}"
echo "[*] VERSION=${PARAM_VERSION}"

# add helm repository
helm repo add "argo" "https://argoproj.github.io/argo-helm"

# download chart locally: "--dependency-update" fails
helm dependency update ${PARAM_CHART_PATH}

# Helm 3 flag --include-crds guarantees that CRDs are created first,
# but it might happen that by the time they are used in the same chart they are not ready yet.
# Since the bootstrap is idempotent, to fix the concurrency issue, when it fails apply the template twice
# ERROR 'unable to recognize "STDIN": no matches for kind "???" in version "argoproj.io/v1alpha1"'
bootstrap || bootstrap

echo "[-] bootstrap"
