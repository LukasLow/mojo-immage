# syntax=docker/dockerfile:1
#
# Example multi-stage app: shows the user workflow.
#
#   Stage "build":  builds the binary with the mojo-immage build image.
#   Stage "run":    runs it with a minimal debian:bookworm-slim runtime.
#
# Build:
#   docker build -t hello-mojo ./examples
# Run:
#   docker run --rm hello-mojo
#
# The build stage pulls the build image from the registry. In CI the freshly
# built image is used locally by passing --build-arg MOJO_IMAGE, e.g.:
#   docker build --build-arg MOJO_IMAGE=ghcr.io/lukaslow/mojo:1.0.0 -t mojo-hello-test ./examples

ARG MOJO_IMAGE=ghcr.io/lukaslow/mojo:1.0.0

# ---- Build stage ----
FROM ${MOJO_IMAGE} AS build

WORKDIR /app
COPY hello.mojo ./
RUN mojo build hello.mojo -o /app/hello

# ---- Run stage ----
FROM debian:bookworm-slim

# The Mojo binary is NOT static — it links against libraries from the pixi
# environment. Copy the whole pixi environment from the build stage and expose
# the dynamic libraries via LD_LIBRARY_PATH. MODULAR_HOME points to the
# modular.cfg inside the pixi environment in case a compiled binary needs it
# at runtime (the default /root/.modular does not exist in the container).
COPY --from=build /opt/mojo/.pixi /opt/mojo/.pixi

ENV MOJO_VERSION=1.0.0 \
    MODULAR_HOME="/opt/mojo/.pixi/envs/default/share/max" \
    PATH="/opt/mojo/.pixi/envs/default/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/mojo/.pixi/envs/default/lib"

COPY --from=build /app/hello /usr/local/bin/hello

ENTRYPOINT ["hello"]
