#!/usr/bin/env bash
#
# Lokaler Dev-Build: baut beide Images mit der NATIVEN Architektur (--load).
# Push (multi-arch) übernimmt ausschließlich die CI (GitHub Actions) mit
# docker/build-push-action — kein separates push-Skript nötig.
#
#   ./scripts/build.sh              # baut mit der Version aus VERSION
#   MOJO_VERSION=1.0.0 ./scripts/build.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Version bestimmen: explizit via MOJO_VERSION oder aus VERSION-Datei.
MOJO_VERSION="${MOJO_VERSION:-$(cat VERSION)}"
REGISTRY="${REGISTRY:-ghcr.io/lukaslow/mojo}"
PLATFORM="$(uname -m)"  # nur zur Info; --load nutzt die native Plattform

echo "=== mojo-immage lokaler Build ==="
echo "Version:  ${MOJO_VERSION}"
echo "Registry: ${REGISTRY}"

# ---- Build-Image ----
echo
echo ">>> Build-Image: ${REGISTRY}:${MOJO_VERSION}"
docker buildx build \
    --load \
    -t "${REGISTRY}:${MOJO_VERSION}" \
    -t "${REGISTRY}:latest" \
    --build-arg MOJO_VERSION="${MOJO_VERSION}" \
    .

# ---- Runtime-Image ----
echo
echo ">>> Runtime-Image: ${REGISTRY}:${MOJO_VERSION}-runtime"
docker buildx build \
    --load \
    -t "${REGISTRY}:${MOJO_VERSION}-runtime" \
    -t "${REGISTRY}:latest-runtime" \
    --build-arg MOJO_VERSION="${MOJO_VERSION}" \
    --build-arg REGISTRY="${REGISTRY}" \
    ./runtime

echo
echo "Fertig. Lokal gebaut (native Plattform: ${PLATFORM})."
