#!/usr/bin/env bash
set -euo pipefail

export CIBUILD_RUN_CMD="$1"
export CIBUILDER_BIN_URL="$2"
export CIBUILDER_BIN_REF="$3"
IMAGE="$4"

env | grep '^GITHUB_' > github.env
env | grep '^ACTIONS_' >> github.env
env | grep '^CIBUILD_' >> github.env
env | grep '^CIBUILDER_' >> github.env

docker run --privileged --rm \
  --env-file github.env \
  -v "$PWD:/workspace" \
  -w /workspace \
  "$IMAGE"

rm -f github.env