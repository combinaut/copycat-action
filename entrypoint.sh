#!/bin/bash
#
# @author André Storhaug <andr3.storhaug@gmail.com>
# @date 2020-03-09
# @license MIT
# @version 3.0.0

set -o pipefail

shopt -s extglob globstar nullglob dotglob

PERSONAL_TOKEN="$INPUT_PERSONAL_TOKEN"
SRC_PATH="$INPUT_SRC_PATH"
DST_PATH="$INPUT_DST_PATH"
DST_OWNER="$INPUT_DST_OWNER"
DST_REPO_NAME="$INPUT_DST_REPO_NAME"
SRC_BRANCH="$INPUT_SRC_BRANCH"
DST_BRANCH="$INPUT_DST_BRANCH"
CLEAN="$INPUT_CLEAN"
FILE_FILTER="$INPUT_FILE_FILTER"
FILTER="$INPUT_FILTER"
EXCLUDE="$INPUT_EXCLUDE"
INCLUDE="$INPUT_INCLUDE"
SRC_WIKI="$INPUT_SRC_WIKI"
DST_WIKI="$INPUT_DST_WIKI"
USERNAME="$INPUT_USERNAME"
EMAIL="$INPUT_EMAIL"

if [[ -z "$SRC_PATH" ]]; then
    echo "SRC_PATH environment variable is missing. Cannot proceed."
    exit 1
fi

if [[ -z "$DST_OWNER" ]]; then
    echo "DST_OWNER environment variable is missing. Cannot proceed."
    exit 1
fi

if [[ -z "$DST_REPO_NAME" ]]; then
    echo "DST_REPO_NAME environment variable is missing. Cannot proceed."
    exit 1
fi

if [ "$SRC_WIKI" = "true" ]; then
    SRC_WIKI=".wiki"
else
    SRC_WIKI=""
fi

if [ "$DST_WIKI" = "true" ]; then
    DST_WIKI=".wiki"
else
    DST_WIKI=""
fi

if [[ -n "$EXCLUDE" && -z "$FILTER" ]]; then
    FILTER="**"
fi

BASE_PATH=$(pwd)
DST_PATH="${DST_PATH:-${SRC_PATH}}"

USERNAME="${USERNAME:-${GITHUB_ACTOR}}"
EMAIL="${EMAIL:-${GITHUB_ACTOR}@users.noreply.github.com}"

SRC_BRANCH="${SRC_BRANCH:-master}"
DST_BRANCH="${DST_BRANCH:-master}"

SRC_REPO="${GITHUB_REPOSITORY}${SRC_WIKI}"
SRC_REPO_NAME="${GITHUB_REPOSITORY#*/}${SRC_WIKI}"
DST_REPO="${DST_OWNER}/${DST_REPO_NAME}${DST_WIKI}"
DST_REPO_NAME="${DST_REPO_NAME}${DST_WIKI}"

FINAL_SOURCE="${SRC_REPO_NAME}/${SRC_PATH}"

git config --global user.name "${USERNAME}"
git config --global user.email "${EMAIL}"

if [[ -z "$FILE_FILTER" ]]; then
    echo "Copying \"${SRC_REPO_NAME}/${SRC_PATH}\" and pushing it to ${GITHUB_REPOSITORY}"
else
    echo "Copying files matching \"${FILE_FILTER}\" from \"${SRC_REPO_NAME}/${SRC_PATH}\" and pushing it to ${GITHUB_REPOSITORY}"
fi

git clone --branch ${SRC_BRANCH} --single-branch --depth 1 https://${PERSONAL_TOKEN}@github.com/${SRC_REPO}.git
if [ "$?" -ne 0 ]; then
    echo >&2 "Cloning '$SRC_REPO' failed"
    exit 1
fi
rm -rf ${SRC_REPO_NAME}/.git

if [[ -n "$FILE_FILTER" ]]; then
    find ${SRC_REPO_NAME}/ -type f -not -name "${FILE_FILTER}" -exec rm {} \;
fi

if [[ -n "$FILTER" ]]; then
    tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
    mkdir ${temp_dir}/${SRC_REPO_NAME}
    cd ${SRC_REPO_NAME}
    FINAL_SOURCE="${tmp_dir}/${SRC_REPO_NAME}/${SRC_PATH}"
    for f in ${FILTER} ; do
        [ -e "$f" ] || continue
        [ -d "$f" ] && continue
        if [[ -n "$EXCLUDE" ]] ; then
            [[ $f == $EXCLUDE ]] && [[ $f != $INCLUDE ]] && continue
        fi
        file_dir=$(dirname "${f}")
        mkdir -p ${tmp_dir}/${SRC_REPO_NAME}/${file_dir} && cp "${f}" ${tmp_dir}/${SRC_REPO_NAME}/${file_dir}
    done
    cd ..
fi

git clone --branch ${DST_BRANCH} --single-branch --depth 1 https://${PERSONAL_TOKEN}@github.com/${DST_REPO}.git
if [ "$?" -ne 0 ]; then
    echo >&2 "Cloning '$DST_REPO' failed"
    exit 1
fi

if [ "$CLEAN" = "true" ]; then
    if [ -f "${DST_REPO_NAME}/${DST_PATH}" ] ; then
        find ${DST_REPO_NAME}/${DST_PATH} -type f -not -path '*/\.git/*' -delete
    elif [ -d "${DST_REPO_NAME}/${DST_PATH}" ] ; then
        find ${DST_REPO_NAME}/${DST_PATH%/*}/* -type f -not -path '*/\.git/*' -delete
    else
        echo >&2 "Nothing to clean 🧽"
    fi
fi

mkdir -p ${DST_REPO_NAME}/${DST_PATH%/*} || exit "$?"
cp -rf ${FINAL_SOURCE} ${DST_REPO_NAME}/${DST_PATH} || exit "$?"
cd ${DST_REPO_NAME} || exit "$?"

if [ -z "$(git status --porcelain)" ]; then
    # Working directory is clean
    echo "No changes detected "
else
    # Uncommitted changes
    git add -A
    git commit --message "Import updates from base app"
    git push origin ${DST_BRANCH}
fi

echo "Copying complete 👌"
