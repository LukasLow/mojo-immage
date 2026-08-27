# syntax=docker/dockerfile:1
#
# mojo-immage — Build-/Dev-Image für Mojo 1.0 (Modular, CLI `mojo`).
#
# Dieses Image enthält die komplette Mojo-Toolchain über pixi (conda).
# Es ist als "builder" für Multi-Stage-Builds gedacht:
#
#   FROM ghcr.io/lukaslow/mojo:1.0.0 AS build
#   COPY app.mojo ./
#   RUN mojo build app.mojo -o /app/app
#
# Basis ist debian:bookworm-slim (glibc). NICHT alpine — pixi/conda-Pakete
# sind glibc-basiert und brechen unter musl (siehe README).

# ---- Konfiguration ----
ARG MOJO_VERSION=1.0.0

FROM debian:bookworm-slim

ARG MOJO_VERSION

# Installiere die Mindestmenge an Paketen:
#   curl            → pixi-Installationsskript herunterladen
#   ca-certificates → HTTPS-Downloads
#   git             → pixi kann für Channel-Metadaten git brauchen
#   bash            → pixi-Installationsskript
#   gcc + libc6-dev → der Mojo-Compiler braucht beim Linken einen C-Compiler
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        bash \
        gcc \
        libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# pixi offiziell installieren → installiert nach ~/.pixi, hier /root/.pixi.
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:${PATH}"

# pixi-Projekt anlegen und Mojo installieren.
# Die pixi.toml wird per heredoc mit der ARG-Version generiert, damit
# MOJO_VERSION nur an einer Stelle gepflegt wird. Zuerst installieren,
# damit das Mojo-Image-Caching nicht durch spätere Layer zerstört wird.
WORKDIR /opt/mojo

# Version in die pixi.toml einsetzen (>=x,<2 statt exakt == → robuster,
# erlaubt patch/revision-Updates der Conda-Builds innerhalb der Major-Version).
# Heredoc mit unquotiertem Delimiter: ${MOJO_VERSION} wird von der Shell expandiert.
RUN cat > pixi.toml <<EOF && pixi install
[project]
name = "mojo"
channels = ["https://conda.modular.com/max/", "conda-forge"]
platforms = ["linux-64", "linux-aarch64"]

[dependencies]
mojo = ">=${MOJO_VERSION},<2"
EOF

# Build-Verifikation: schlägt fehl, wenn Mojo nicht startet → CI bricht früh.
RUN pixi run mojo --version

# Build-Time-Verifikation mit std: kompiliert und führt ein echtes Programm aus.
# Bricht den Image-Build früh ab, falls die std-Library fehlt oder der Compiler
# die modular.cfg nicht findet (Mojo-v1-Syntax: def, Einrückung).
# mojo wird via pixi run aufgerufen (conda-env wird erst durch pixi aktiviert).
RUN printf 'def main():\n    print("std-ok")\n' > /tmp/stdtest.mojo \
    && pixi run mojo build /tmp/stdtest.mojo -o /tmp/stdtest \
    && /tmp/stdtest \
    && rm -f /tmp/stdtest /tmp/stdtest.mojo

# Umgebungsvariablen für die pixi-Environment (default env).
# MODULAR_HOME zeigt auf das Verzeichnis mit der modular.cfg. Ohne diese Variable
# sucht der Mojo-Compiler unter dem Default /root/.modular, das im Container nicht
# existiert → "modular.cfg not found". Die cfg liegt in der pixi-Environment.
ENV MOJO_VERSION=${MOJO_VERSION} \
    MODULAR_HOME="/opt/mojo/.pixi/envs/default/share/max" \
    PATH="/opt/mojo/.pixi/envs/default/bin:/root/.pixi/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/mojo/.pixi/envs/default/lib"

# Arbeitsverzeichnis für User-Projekte (world-writable, GOPATH-/GOROOT-Konvention).
WORKDIR /mojo
RUN mkdir -p /mojo && chmod 1777 /mojo

# Kein ENTRYPOINT. CMD zeigt die Version beim `docker run` ohne Argumente.
# mojo liegt direkt im PATH (/opt/mojo/.pixi/envs/default/bin), pixi run ist
# nicht nötig (pixi bräuchte sonst eine pixi.toml im CWD).
CMD ["mojo", "--version"]
