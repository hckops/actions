#!/bin/bash

set -euo pipefail

##############################

PARAM_ACTION=${1:?"Missing ACTION"}
PARAM_WEBHOOK_URL=${2:?"Missing WEBHOOK_URL"}

##############################

echo "[+] discord"
echo "[*] ACTION=${PARAM_ACTION}"
echo "[*] WEBHOOK_URL=${PARAM_WEBHOOK_URL}"

case ${PARAM_ACTION} in
  # https://discord.com/developers/docs/resources/channel#create-message
  "create-message")
    PARAM_MESSAGE=${3:-"EMPTY_MESSAGE"}
    curl -sS \
      -H "Content-Type: application/json" \
      -d '{"content":"'${PARAM_MESSAGE}'"}' \
      ${PARAM_WEBHOOK_URL}
  ;;
  *)
    echo "ERROR: unknown command"
    exit 1
  ;;
esac

echo "[-] discord"
