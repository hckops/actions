#!/bin/bash

set -euo pipefail

##############################

PARAM_GITOPS_SSH_KEY=${1:?"Missing GITOPS_SSH_KEY"}
PARAM_ARGOCD_ADMIN_PASSWORD=${2:?"Missing ARGOCD_ADMIN_PASSWORD"}
PARAM_KUBECONFIG=${3:?"Missing KUBECONFIG"}
PARAM_CHART_PATH=${4:?"Missing CHART_PATH"}
# optional config override
PARAM_CONFIG_PATH=${5:-"INVALID_CONFIG_PATH"}
# NOT IMPLEMENTED: uses always latest config in the current branch
PARAM_CONFIG_BRANCH=${6:-"HEAD"}

##############################

# param #1: <string>
# param #2: <string>
function get_config {
  local FIELD_NAME=$1
  local DEFAULT_VALUE=$2

  # if config file doesn't exist returns default
  if [[ -f "${PARAM_CONFIG_PATH}" ]]; then
    echo $(yq -o=json '.' "${PARAM_CONFIG_PATH}" | jq -r '.bootstrap.'"${FIELD_NAME}"' // "'"${DEFAULT_VALUE}"'"')
  else
    echo ${DEFAULT_VALUE}
  fi
}

function bootstrap {
  local CHART_NAME=$(get_config "chartName" "argocd")
  # https://helm.sh/docs/chart_template_guide/subcharts_and_globals/#overriding-values-from-a-parent-chart
  local CHART_NAME_PREFIX=$(get_config "chartNamePrefix" ${CHART_NAME})
  local NAMESPACE=$(get_config "namespace" "argocd")
  # if the file doesn't exist apply the default values twice
  local HELM_VALUE_FILE=$(get_config "helmValueFile" "values.yaml")

  echo "[*] BOOTSTRAP_CHART_NAME=${CHART_NAME}"
  echo "[*] BOOTSTRAP_CHART_NAME_PREFIX=${CHART_NAME_PREFIX}"
  echo "[*] BOOTSTRAP_NAMESPACE=${NAMESPACE}"
  echo "[*] BOOTSTRAP_HELM_VALUE_FILE=${HELM_VALUE_FILE}"

  # manually applies "argocd-config" chart and "argocd" dependency with crds
  # applies in order: values.yaml -> values-bootstrap.yaml -> 2 secret ovverrides
  # argocd-config app uses values.yaml and values-auth.yaml excluding values-bootstrap.yaml
  # values-auth.yaml sets "createSecret: false" to avoid overriding admin password and add SSO independently
  # with "createSecret: true" argocd by default creates a random admin password
  # https://argo-cd.readthedocs.io/en/stable/faq/#i-forgot-the-admin-password-how-do-i-reset-it
  helm template ${CHART_NAME} \
    --include-crds \
    --dependency-update \
    --namespace ${NAMESPACE} \
    --values "${PARAM_CHART_PATH}/values.yaml" \
    --values "${PARAM_CHART_PATH}/${HELM_VALUE_FILE}" \
    --set ${CHART_NAME_PREFIX}.configs.secret.argocdServerAdminPassword="${PARAM_ARGOCD_ADMIN_PASSWORD}" \
    --set ${CHART_NAME_PREFIX}.configs.credentialTemplates.ssh-creds.sshPrivateKey="${PARAM_GITOPS_SSH_KEY}" \
    ${PARAM_CHART_PATH} | kubectl --kubeconfig ${PARAM_KUBECONFIG} --namespace ${NAMESPACE} apply -f -
}

function main {
  # add helm repository
  helm repo add "argo" "https://argoproj.github.io/argo-helm"

  # download chart locally: "--dependency-update" fails
  helm dependency update ${PARAM_CHART_PATH}

  # Helm 3 flag --include-crds guarantees that CRDs are created first,
  # but it might happen that by the time they are used in the same chart they are not ready yet.
  # Since the bootstrap is idempotent, to fix the concurrency issue, when it fails apply the template twice
  # ERROR 'unable to recognize "STDIN": no matches for kind "???" in version "argoproj.io/v1alpha1"'
  bootstrap || bootstrap
}

##############################

echo "[+] bootstrap"
echo "[*] GITOPS_SSH_KEY=${PARAM_GITOPS_SSH_KEY}"
echo "[*] ARGOCD_ADMIN_PASSWORD=${PARAM_ARGOCD_ADMIN_PASSWORD}"
echo "[*] KUBECONFIG=${PARAM_KUBECONFIG}"
echo "[*] CHART_PATH=${PARAM_CHART_PATH}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*][TODO] CONFIG_BRANCH=${PARAM_CONFIG_BRANCH}"

main

echo "[-] bootstrap"
