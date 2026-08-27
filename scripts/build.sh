#!/usr/bin/env bash
#
# Local dev build: builds the build image with the NATIVE architecture (--load).
# Push (multi-arch) is done exclusively by the CI (GitHub Actions) with
# docker/build-push-action — no separate push script needed.
#
#   ./scripts/build.sh              # builds with the version from VERSION
#   MOJO_VERSION=1.0.0 ./scripts/build.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Determine version: explicitly via MOJO_VERSION or from the VERSION file.
MOJO_VERSION="${MOJO_VERSION:-$(cat VERSION)}"
REGISTRY="${REGISTRY:-ghcr.io/lukaslow/mojo}"
PLATFORM="$(uname -m)"  # informational only; --load uses the native platform
MAJOR_MINOR="${MOJO_VERSION%.*}"  # 1.0.0 → 1.0

echo "=== mojo-immage local build ==="
echo "Version:  ${MOJO_VERSION}"
echo "Registry: ${REGISTRY}"

# ---- Build image ----
echo
echo ">>> Build image: ${REGISTRY}:${MOJO_VERSION}"
docker buildx build \
    --load \
    -t "${REGISTRY}:${MOJO_VERSION}" \
    -t "${REGISTRY}:${MAJOR_MINOR}" \
    -t "${REGISTRY}:latest" \
    --build-arg MOJO_VERSION="${MOJO_VERSION}" \
    .

echo
echo "Done. Built locally (native platform: ${PLATFORM})."
