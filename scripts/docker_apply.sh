#!/bin/bash

set -euo pipefail

CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd ${CURRENT_PATH}

##############################

PARAM_ACTION=${1:?"Missing ACTION"}
PARAM_IMAGE_NAME=${2:?"Missing IMAGE_NAME"}

DOCKER_REPOSITORY="hckops/kube-${PARAM_IMAGE_NAME}"

ROOT_PATH="${CURRENT_PATH}/.."

##############################

echo "[+] docker_apply"
echo "[*] ACTION=${PARAM_ACTION}"
echo "[*] IMAGE_NAME=${PARAM_IMAGE_NAME}"
echo "[*] DOCKER_REPOSITORY=${DOCKER_REPOSITORY}"

case ${PARAM_ACTION} in
  "build")
    cd "${ROOT_PATH}/docker"

    docker build -t ${DOCKER_REPOSITORY} -f "Dockerfile.${PARAM_IMAGE_NAME}" .
  ;;
  "publish")
    # example "vX.Y.Z"
    PARAM_VERSION=${3:?"Missing VERSION"}
    # remove prefix "v"
    VERSION=${PARAM_VERSION#"v"}
    echo "[*] VERSION=${VERSION}"

    docker tag ${DOCKER_REPOSITORY} "${DOCKER_REPOSITORY}:${VERSION}"
    docker tag ${DOCKER_REPOSITORY} "${DOCKER_REPOSITORY}:latest"

    docker image push --all-tags ${DOCKER_REPOSITORY}
  ;;
  "clean")
    # remove container by name
    docker ps -a -q -f name=${DOCKER_REPOSITORY} | xargs --no-run-if-empty docker rm -f
    # delete dangling images <none>
    docker images -q -f dangling=true | xargs --no-run-if-empty docker rmi -f
    # remove image by name
    docker images -q ${DOCKER_REPOSITORY} | xargs --no-run-if-empty docker rmi -f
    # delete dangling volumes
    docker volume ls -q -f dangling=true | xargs --no-run-if-empty docker volume rm -f
  ;;
  *)
    echo "ERROR: unknown command"
    exit 1
  ;;
esac

echo "[-] docker_apply"
