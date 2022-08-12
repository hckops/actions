#!/bin/bash

set -euo pipefail

##############################

echo "[+] helm-lint"

find . -type f -name 'Chart.yaml' -exec dirname {} \; | xargs helm lint

echo "[-] helm-lint"
