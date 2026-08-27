# mojo-immage

Official Docker image for the **Mojo 1.0** programming language (Modular, CLI `mojo`).
There is no official Mojo Docker image, so this repo provides one reference image:

| Image | Tag example | Purpose |
|-------|-------------|---------|
| `ghcr.io/lukaslow/mojo` | `1.0.0`, `1.0`, `latest` | **Build/Dev image** — full Mojo toolchain (pixi), for multi-stage builds |

## Structure

```
.
├── Dockerfile               # Build/Dev image (debian:bookworm-slim + pixi + Mojo)
├── examples/                # Example app: hello.mojo + multi-stage Dockerfile
├── scripts/build.sh         # Local dev build (native arch, no push)
├── .github/workflows/ci.yml # GitHub Actions: build → test → multi-arch push to GHCR
└── VERSION                  # Central version ("1.0.0")
```

## Quickstart

### Use the build image directly

```bash
# Show the version:
docker run --rm ghcr.io/lukaslow/mojo:1.0.0

# Interactive shell with the Mojo toolchain:
docker run --rm -it ghcr.io/lukaslow/mojo:1.0.0 bash
```

### Build your own app (user workflow)

```bash
# Build locally:
cd examples
docker build -t hello-mojo .
docker run --rm hello-mojo     # → "hello from mojo"
```

This is what the user workflow looks like (see `examples/Dockerfile`):

```dockerfile
FROM ghcr.io/lukaslow/mojo:1.0.0 AS build
COPY app.mojo ./
RUN mojo build app.mojo -o /app/app

FROM debian:bookworm-slim
COPY --from=build /opt/mojo/.pixi /opt/mojo/.pixi
ENV MODULAR_HOME="/opt/mojo/.pixi/envs/default/share/max" \
    LD_LIBRARY_PATH="/opt/mojo/.pixi/envs/default/lib"
COPY --from=build /app/app /usr/local/bin/app
ENTRYPOINT ["app"]
```

### Deployment (own minimal runtime)

Build your binary with this image, then run it on any minimal runtime that ships
the Mojo runtime libraries (e.g. `debian:bookworm-slim` + the binary, as shown
above in the example). No separate runtime image is published — the `examples/Dockerfile`
is a ready-to-use template for that pattern.

## Usage

`mojo` is available in the build/Dev image **directly on the PATH**
(`/opt/mojo/.pixi/envs/default/bin`) — **no `pixi run` needed**. You can call the
binary directly and compile inside the container:

```bash
# Show the version (the CMD-`docker run` without arguments also shows it):
docker run --rm ghcr.io/lukaslow/mojo:1.0.0 mojo --version

# Compile and run inside the container:
docker run --rm -it ghcr.io/lukaslow/mojo:1.0.0 bash
#   $ echo 'def main(): print("hi")' > hi.mojo
#   $ mojo build hi.mojo -o hi
#   $ ./hi
```

## Tags

The version comes from the central `VERSION` file (currently `1.0.0`). Each version
is pushed with three tags:

| Source | Tags |
|--------|------|
| `VERSION = 1.0.0` | `1.0.0`, `1.0`, `latest` |

`latest` therefore always points to the most recently built version.

## Version bump

1. Change the `VERSION` file (e.g. `1.0.0` → `1.0.1`).
2. Push to `main`.
3. CI builds (arm64 + amd64), runs the example app as a test, and pushes to GHCR.

**Old versions remain** — a new version entry does not overwrite existing tags,
it adds new ones. Rollbacks are therefore always possible.

## Multi-arch

The image is built with `docker buildx` for `linux/arm64` **and** `linux/amd64`
and pushed as a multi-arch manifest. That happens in the CI (`.github/workflows/ci.yml`).

The local `scripts/build.sh` builds only the **native** platform (`--load`), because
`docker buildx --load` cannot load multi-platform builds into the local daemon.
Pushing is handled exclusively by the CI.

## Base decision: debian:bookworm-slim

The image is based on `debian:bookworm-slim` (glibc). **Not alpine:**

- pixi/conda packages are **glibc-based** and break under alpine (musl libc).
- Mojo is installed via the conda channel `https://conda.modular.com/max/`;
  its binaries expect glibc.
- Debian bookworm-slim is already slim (glibc included, no redundancy).

The build image additionally installs `gcc` + `libc6-dev`, because the Mojo compiler
needs a C compiler when linking (verified in the benchmark repo).

## Registry

Registry: **`ghcr.io/lukaslow/mojo`** (GitHub Container Registry).

CI trigger: push to `main` (or manual via `workflow_dispatch`).
