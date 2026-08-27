# syntax=docker/dockerfile:1
#
# mojo-immage — Runtime-Image für Mojo-Binaries.
#
# Der User baut sein Binary mit dem Build-Image (ghcr.io/lukaslow/mojo:<v>)
# und kopiert es hier rein. Dieses Image stellt die Mojo-Laufzeit-Libraries
# bereit (die komplette pixi-Environment, da das Mojo-Binary NICHT statisch
# ist und gegen Libraries aus der pixi-Umgebung linkt — siehe Benchmark-Repo).
#
# ACHTUNG: Dieses Image hängt am Build-Image (COPY --from=libs). Es kann daher
# erst gebaut werden, wenn ghcr.io/lukaslow/mojo:<v> existiert. Das ist Absicht
# und spart Duplikation (ein Ort für die Toolchain) — siehe main.md / README.

# ---- Konfiguration ----
ARG MOJO_VERSION=1.0.0
ARG REGISTRY=ghcr.io/lukaslow/mojo

# ---- Stage "libs": pixi-Environment aus dem Build-Image holen ----
FROM ${REGISTRY}:${MOJO_VERSION} AS libs

# ---- Stage "runtime": schlankes Deployment-Image ----
FROM debian:bookworm-slim

ARG MOJO_VERSION

# Basis-Laufzeit-Libs: glibc ist in bookworm-slim enthalten; libgomp für
# OpenMP, falls das Mojo-Runtime sie braucht (wie im Benchmark-Repo).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Komplette pixi-Environment mitkopieren (enthält die dynamischen Libs,
# die das Mojo-Binary zur Laufzeit braucht).
COPY --from=libs /opt/mojo/.pixi /opt/mojo/.pixi

# Dynamische Libs sichtbar machen + Tools des envs auf den PATH
# (vorsichtshalber, falls das Binary Tools benötigt).
# MODULAR_HOME zeigt auf die modular.cfg in der pixi-Environment — falls ein
# kompiliertes Binary zur Laufzeit die cfg braucht, ist sie damit auffindbar
# (Default /root/.modular existiert im Container nicht).
ENV MOJO_VERSION=${MOJO_VERSION} \
    MODULAR_HOME="/opt/mojo/.pixi/envs/default/share/max" \
    PATH="/opt/mojo/.pixi/envs/default/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/mojo/.pixi/envs/default/lib"

# Kein ENTRYPOINT/CMD — der User setzt sein eigenes für sein Binary.
