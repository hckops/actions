#!/bin/bash

set -euo pipefail

##############################

PARAM_GIT_USER_EMAIL=${1:?"Missing GIT_USER_EMAIL"}
PARAM_GIT_USER_NAME=${2:?"Missing GIT_USER_NAME"}
PARAM_GIT_DEFAULT_BRANCH=${3:?"Missing GIT_DEFAULT_BRANCH"}
PARAM_CONFIG_PATH=${4:?"Missing CONFIG_PATH"}
PARAM_DRY_RUN=${5:?"Missing DRY_RUN"}

##############################

# param #1: <string>
# param #2: <string>
function get_config {
  local CONFIG_PATH=$1
  local JQ_PATH=$2

  echo $(yq -o=json '.' "${CONFIG_PATH}" | jq -r "${JQ_PATH}")
}

# param #1: <string>
function get_latest_artifacthub {
  # owner/repository
  local HELM_NAME=$1

  # fetches latest version from rss feed (xml format)
  echo $(curl -sSL "https://artifacthub.io/api/v1/packages/helm/$HELM_NAME/feed/rss" | \
    yq -p=xml '.rss.channel.item[0].title')
}

# global param: <PARAM_GIT_USER_EMAIL>
# global param: <PARAM_GIT_USER_NAME>
function init_git {
  # fixes: unsafe repository ('/github/workspace' is owned by someone else)
  git config --global --add safe.directory /github/workspace

  # mandatory configs
  git config user.email $PARAM_GIT_USER_EMAIL
  git config user.name $PARAM_GIT_USER_NAME

  # fetch existing remote branches
  git fetch --all
}

# global param: <PARAM_GIT_DEFAULT_BRANCH>
function reset_git {
  # stash any changes from previous pr
  git stash save -u

  # reset to default branch
  git checkout $PARAM_GIT_DEFAULT_BRANCH
}

# param #1: <string>
# param #2: <string>
# param #3: <string>
# global param: <PARAM_GIT_DEFAULT_BRANCH>
# action param: <GITHUB_TOKEN> (hidden)
# see https://github.com/my-awesome/actions/blob/main/gh-update-action/update.sh
function create_pr {
  local GIT_BRANCH=$1
  local PR_TITLE=$2
  local PR_MESSAGE=$3

  echo "[*] GIT_BRANCH=${GIT_BRANCH}"
  echo "[*] PR_TITLE=${PR_TITLE}"
  echo "[*] PR_MESSAGE=${PR_MESSAGE}"

  # must be on a different branch
  git checkout -b $GIT_BRANCH
  git add .
  git status

  # fails without quotes: "quote all values that have spaces"
  git commit -m "$PR_MESSAGE"
  git push origin $GIT_BRANCH

  # uses GITHUB_TOKEN
  gh pr create --head $GIT_BRANCH --base ${PARAM_GIT_DEFAULT_BRANCH} --title "$PR_TITLE" --body "$PR_MESSAGE"
  
  # TODO labels https://github.com/cli/cli/issues/1503
  # TODO automerge
}

# param #1: <string>
# global param: <PARAM_DRY_RUN>
function update_dependency {
  local DEPENDENCY_JSON=$1
  local REPOSITORY_TYPE=$(echo ${DEPENDENCY_JSON} | jq -r '.repository.type')

  # debug
  echo ${DEPENDENCY_JSON} | jq '.'

  case ${REPOSITORY_TYPE} in
    "artifacthub")
      local REPOSITORY_NAME=$(echo ${DEPENDENCY_JSON} | jq -r '.repository.name')
      local SOURCE_FILE=$(echo ${DEPENDENCY_JSON} | jq -r '.source.file')
      local SOURCE_PATH=$(echo ${DEPENDENCY_JSON} | jq -r '.source.path')
      local CURRENT_VERSION=$(get_config ${SOURCE_FILE} ${SOURCE_PATH})
      local LATEST_VERSION=$(get_latest_artifacthub ${REPOSITORY_NAME})

      echo "[${REPOSITORY_NAME}] CURRENT=[${CURRENT_VERSION}] LATEST=[${LATEST_VERSION}]"

      if [[ ${CURRENT_VERSION} != ${LATEST_VERSION} ]]; then
        echo "[-] Dependency is already up to date"

      elif [[ "${PARAM_DRY_RUN}" == "true" ]]; then
        echo "[-] Skip pull request: dry run"

      else
        # update version: see formatting issue https://github.com/mikefarah/yq/issues/515
        yq -i  "${SOURCE_PATH} = \"${LATEST_VERSION}\"" ${SOURCE_FILE}

        local GIT_BRANCH=$(echo "helm-${REPOSITORY_NAME}-${LATEST_VERSION}" | sed -r 's|[/.]|-|g')
        local DEPENDENCY_NAME=$(basename ${REPOSITORY_NAME})
        local PR_TITLE="Update ${DEPENDENCY_NAME} to ${LATEST_VERSION}"
        local PR_MESSAGE="Updates [${REPOSITORY_NAME}](https://artifacthub.io/packages/helm/${REPOSITORY_NAME}) Helm dependency from ${CURRENT_VERSION} to ${LATEST_VERSION}"

        # returns the hash of the branch if exists or nothing
        # IMPORTANT branches are fetched once during setup
        local GIT_BRANCH_EXISTS=$(git show-ref ${GIT_BRANCH})

        # returns true if the string is not empty
        if [[ -n ${GIT_BRANCH_EXISTS} ]]; then
          echo "[-] Pull request already exists"
        else
          create_pr "${GIT_BRANCH}" "${PR_TITLE}" "${PR_MESSAGE}"
        fi
      fi
    ;;
    *)
      echo "ERROR: invalid repository type"
      exit 1
    ;;
  esac
}

##############################

function main {
  local DEPENDENCIES=$(get_config ${PARAM_CONFIG_PATH} '.dependencies[]')

  # setup git repository
  init_git

  # use the compact output option (-c) so each result is put on a single line and is treated as one item in the loop
  echo ${DEPENDENCIES} | jq -c '.' | while read ITEM; do
    update_dependency "${ITEM}"

    # prepare git repository for next pr
    reset_git
  done
}

echo "[+] helm-dependencies"
# global
echo "[*] GITHUB_TOKEN=${GITHUB_TOKEN}"
# params
echo "[*] GIT_USER_EMAIL=${PARAM_GIT_USER_EMAIL}"
echo "[*] GIT_USER_NAME=${PARAM_GIT_USER_NAME}"
echo "[*] GIT_DEFAULT_BRANCH=${PARAM_GIT_DEFAULT_BRANCH}"
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] DRY_RUN=${PARAM_DRY_RUN}"

gh --version

main

echo "[-] helm-dependencies"
