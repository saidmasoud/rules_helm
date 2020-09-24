#!/usr/bin/env bash

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
set -euo pipefail
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---
#export RUNFILES_LIB_DEBUG=1

platform=$(uname)
if [ "$platform" == "Darwin" ]; then
    BINARY=$(rlocation helm_osx/darwin-amd64/helm)
elif [ "$platform" == "Linux" ]; then
    BINARY=$(rlocation helm/linux-amd64/helm)
else
    echo "Helm does not have a binary for $platform"
    exit 1
fi

export HELM_HOME="$(pwd)/.helm"
export PATH="$(dirname $BINARY):$PATH"

pwd
cd "${BUILD_WORKING_DIRECTORY:-}"
pwd


while [ $PWD != "/" ]; do
    if [[ -e "WORKSPACE" ]] ; then
        break
    fi
    cd $(dirname $PWD)
    echo "moved to $PWD"
done

ls -lthra
echo "Running in $PWD"

cd "${BUILD_WORKING_DIRECTORY:-}"
helm $*
