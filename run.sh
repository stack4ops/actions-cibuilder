#!/usr/bin/env bash
set -euo pipefail

export CIBUILD_RUN_CMD="$1"
export CIBUILDER_BIN_URL="$2"
export CIBUILDER_BIN_REF="$3"
IMAGE="$4"

CIBUILD_OUTPUT="${RUNNER_TEMP:-/tmp}/cibuild-output"
mkdir -p "${CIBUILD_OUTPUT}"
chmod 1777 "${CIBUILD_OUTPUT}"

env | grep '^GITHUB_' > github.env
env | grep '^ACTIONS_' >> github.env
env | grep '^CIBUILD_' >> github.env
env | grep '^CIBUILDER_' >> github.env
echo "CIBUILD_OUTPUT_DIR=/cibuild-output" >> github.env

docker run --privileged --rm \
  --env-file github.env \
  -v "$PWD:/workspace" \
  -v "${CIBUILD_OUTPUT}:/cibuild-output" \
  -w /workspace \
  "$IMAGE"

rm -f github.env