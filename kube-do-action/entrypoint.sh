#!/bin/bash

set -euo pipefail

##############################

PARAM_ACCESS_TOKEN=${1:?"Missing ACCESS_TOKEN"}
PARAM_CONFIG_PATH=${2:?"Missing CONFIG_PATH"}
PARAM_ENABLED=${3:?"Missing ENABLED"}

##############################

echo "[+] kube-do"
echo "[*] ACCESS_TOKEN=${PARAM_ACCESS_TOKEN}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] ENABLED=${PARAM_ENABLED}"

git status
#git clone --branch=main --depth=1 git@github.com:hckops/actions.git /tmp/action-main

echo "::set-output name=status::OK"

echo "[-] kube-do"
