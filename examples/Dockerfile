# syntax=docker/dockerfile:1
#
# Beispiel-Multi-Stage-App: zeigt den User-Workflow.
#
#   Stage "build":  baut das Binary mit dem mojo-immage Build-Image.
#   Stage "run":    führt es mit dem mojo-immage Runtime-Image aus.
#
# Bauen:
#   docker build -t hello-mojo ./examples
# Ausführen:
#   docker run --rm hello-mojo

ARG MOJO_VERSION=1.0.0
ARG REGISTRY=ghcr.io/lukaslow/mojo

# ---- Build-Stage ----
FROM ${REGISTRY}:${MOJO_VERSION} AS build
ARG MOJO_VERSION

WORKDIR /app
COPY hello.mojo ./
RUN mojo build hello.mojo -o /app/hello

# ---- Run-Stage ----
FROM ${REGISTRY}:${MOJO_VERSION}-runtime

COPY --from=build /app/hello /usr/local/bin/hello

ENTRYPOINT ["hello"]
