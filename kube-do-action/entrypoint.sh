#!/bin/bash

set -euo pipefail

##############################

PARAM_GITHUB_TOKEN=${1:?"Missing GITHUB_TOKEN"}
PARAM_ACCESS_TOKEN=${2:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${3:?"Missing CONFIG_PATH"}
PARAM_ENABLED=${4:?"Missing ENABLED"}

##############################

echo "[+] kube-do"
echo "[*] GITHUB_TOKEN=${PARAM_GITHUB_TOKEN}"
echo "[*] ACCESS_TOKEN=${PARAM_ACCESS_TOKEN}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] ENABLED=${PARAM_ENABLED}"

printenv

# downloads only the last 2 commits
curl -sSL -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/commits?per_page=2&page=1"

# TODO use the second to last commit sha to download the previous config

curl -sSL -H "Authorization: token ${PARAM_GITHUB_TOKEN}" \
  -H 'Accept: application/vnd.github.v3.raw' \
  -o /tmp/${PARAM_CONFIG_PATH} \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${PARAM_CONFIG_PATH}"

pwd
ls -la /tmp

echo "::set-output name=status::OK"

echo "[-] kube-do"
