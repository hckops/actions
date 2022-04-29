#!/bin/bash

set -euo pipefail

##############################

PARAM_GITHUB_TOKEN=${1:?"Missing GITHUB_TOKEN"}
PARAM_ACCESS_TOKEN=${2:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${3:?"Missing CONFIG_PATH"}
PARAM_ENABLED=${4:?"Missing ENABLED"}

##############################

# global param: <PARAM_GITHUB_TOKEN>
# action param: <GITHUB_REPOSITORY>
# returns SHA
function previous_commit_sha {
  local COMMITS_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/commits?per_page=2&page=1"

  # downloads the last 2 commits and extracts the previous sha
  echo $(curl -sSL \
    -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    ${COMMITS_URL} | jq -r '.[1].sha')
}

# param #1: <string>
# param #2: <string>
# param #3: <string>
# global param: <PARAM_GITHUB_TOKEN>
# action param: <GITHUB_REPOSITORY>
function download_file {
  local FILE_PATH=$1
  local OUTPUT_PATH=$2
  # default ""
  local COMMIT_REF=${3:-""}
  echo "[-] OUTPUT_PATH=${OUTPUT_PATH} | COMMIT_REF=${COMMIT_REF}"

  curl -sSL -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -o ${OUTPUT_PATH} \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${FILE_PATH}?ref=${COMMIT_REF}"
}

##############################

echo "[+] kube-do"
# global
echo "[*] GITHUB_REPOSITORY=${GITHUB_REPOSITORY}"
# params
echo "[*] GITHUB_TOKEN=${PARAM_GITHUB_TOKEN}"
echo "[*] ACCESS_TOKEN=${PARAM_ACCESS_TOKEN}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] ENABLED=${PARAM_ENABLED}"

LATEST_CONFIG_PATH="/tmp/latest"
PREVIOUS_CONFIG_PATH="/tmp/previous"
PREVIOUS_COMMIT=$(previous_commit_sha)

download_file ${PARAM_CONFIG_PATH} ${LATEST_CONFIG_PATH}
download_file ${PARAM_CONFIG_PATH} ${PREVIOUS_CONFIG_PATH} ${PREVIOUS_COMMIT}

ls -la /tmp
# TODO if they are different start/stop cluster
yq -r '.status' ${LATEST_CONFIG_PATH}
yq -r '.status' ${PREVIOUS_CONFIG_PATH

echo "::set-output name=status::OK"

echo "[-] kube-do"
