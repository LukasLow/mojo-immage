# syntax=docker/dockerfile:1
#
# mojo-immage — Build/Dev image for Mojo 1.0 (Modular, CLI `mojo`).
#
# This image contains the complete Mojo toolchain via pixi (conda).
# It is intended as a "builder" for multi-stage builds:
#
#   FROM ghcr.io/lukaslow/mojo:1.0.0 AS build
#   COPY app.mojo ./
#   RUN mojo build app.mojo -o /app/app
#
# Base is debian:bookworm-slim (glibc). NOT alpine — pixi/conda packages are
# glibc-based and break under musl (see README).

# ---- Configuration ----
ARG MOJO_VERSION=1.0.0

FROM debian:bookworm-slim

ARG MOJO_VERSION

# Install the minimal set of packages:
#   curl            → download the pixi installer script
#   ca-certificates → HTTPS downloads
#   git             → pixi may need git for channel metadata
#   bash            → pixi installer script
#   gcc + libc6-dev → the Mojo compiler needs a C compiler when linking
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        bash \
        gcc \
        libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Install pixi officially → installs into ~/.pixi, here /root/.pixi.
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:${PATH}"

# Create a pixi project and install Mojo.
# The pixi.toml is generated via heredoc with the ARG version, so that
# MOJO_VERSION is maintained in only one place. Install first so that the
# Mojo image caching is not broken by later layers.
WORKDIR /opt/mojo

# Substitute the version into pixi.toml (>=x,<2 instead of exact == → more
# robust, allows patch/revision updates of the conda builds within the major
# version). Heredoc with unquoted delimiter: ${MOJO_VERSION} is expanded by the shell.
RUN cat > pixi.toml <<EOF && pixi install
[project]
name = "mojo"
channels = ["https://conda.modular.com/max/", "conda-forge"]
platforms = ["linux-64", "linux-aarch64"]

[dependencies]
mojo = ">=${MOJO_VERSION},<2"
EOF

# Build verification: fails if Mojo does not start → CI breaks early.
RUN pixi run mojo --version

# Build-time verification with std: compiles and runs a real program.
# Aborts the image build early if the std library is missing or the compiler
# cannot find modular.cfg (Mojo v1 syntax: def, indentation).
# mojo is invoked via pixi run (the conda env is only activated by pixi).
RUN printf 'def main():\n    print("std-ok")\n' > /tmp/stdtest.mojo \
    && pixi run mojo build /tmp/stdtest.mojo -o /tmp/stdtest \
    && /tmp/stdtest \
    && rm -f /tmp/stdtest /tmp/stdtest.mojo

# Environment variables for the pixi environment (default env).
# MODULAR_HOME points to the directory containing modular.cfg. Without this
# variable the Mojo compiler looks under the default /root/.modular, which does
# not exist in the container → "modular.cfg not found". The cfg lives in the
# pixi environment.
ENV MOJO_VERSION=${MOJO_VERSION} \
    MODULAR_HOME="/opt/mojo/.pixi/envs/default/share/max" \
    PATH="/opt/mojo/.pixi/envs/default/bin:/root/.pixi/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/mojo/.pixi/envs/default/lib"

# Working directory for user projects (world-writable, GOPATH-/GOROOT-convention).
WORKDIR /mojo
RUN mkdir -p /mojo && chmod 1777 /mojo

# No ENTRYPOINT. CMD shows the version on `docker run` without arguments.
# mojo is directly in the PATH (/opt/mojo/.pixi/envs/default/bin), pixi run is
# not needed (pixi would otherwise need a pixi.toml in the CWD).
CMD ["mojo", "--version"]
