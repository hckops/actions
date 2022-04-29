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

git clone --branch=main --depth=1 "https://${PARAM_GITHUB_TOKEN}@github.com/hckops/actions.git" /tmp/action-main

pwd
ls -la /tmp/action-main

echo "::set-output name=status::OK"

echo "[-] kube-do"
