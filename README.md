# mojo-immage

Offizielle Docker-Images für die Programmiersprache **Mojo 1.0** (Modular, CLI `mojo`).
Es existiert kein offizielles Mojo-Docker-Image, deshalb stellt dieses Repo zwei
Referenz-Images zur Verfügung:

| Image | Tag-Beispiel | Zweck |
|-------|-------------|-------|
| `ghcr.io/lukaslow/mojo` | `1.0.0`, `1.0`, `latest` | **Build-/Dev-Image** — volle Mojo-Toolchain (pixi), für Multi-Stage-Builds |
| `ghcr.io/lukaslow/mojo` | `1.0.0-runtime`, `1.0-runtime`, `latest-runtime` | **Runtime-Image** — schlank, für Deployments von gebauten Mojo-Binaries |

## Struktur

```
.
├── Dockerfile              # Build-/Dev-Image (debian:bookworm-slim + pixi + Mojo)
├── runtime/Dockerfile      # Runtime-Image (debian:bookworm-slim + Mojo-Libs)
├── examples/               # Beispiel-App: hello.mojo + Multi-Stage-Dockerfile
├── scripts/build.sh        # Lokaler Dev-Build (native Arch, kein Push)
├── .github/workflows/ci.yml# GitHub Actions: multi-arch Build + Push nach GHCR
└── VERSION                 # Zentrale Version ("1.0.0")
```

## Quickstart

### Build-Image direkt nutzen

```bash
# Version zeigen:
docker run --rm ghcr.io/lukaslow/mojo:1.0.0

# Interaktive Shell mit Mojo-Toolchain:
docker run --rm -it ghcr.io/lukaslow/mojo:1.0.0 bash
```

### Eigene App bauen (User-Workflow)

```bash
# Lokal bauen:
cd examples
docker build -t hello-mojo .
docker run --rm hello-mojo     # → "hello from mojo"
```

So sieht der User-Workflow aus (siehe `examples/Dockerfile`):

```dockerfile
FROM ghcr.io/lukaslow/mojo:1.0.0 AS build
COPY app.mojo ./
RUN mojo build app.mojo -o /app/app

FROM ghcr.io/lukaslow/mojo:1.0.0-runtime
COPY --from=build /app/app /usr/local/bin/app
ENTRYPOINT ["app"]
```

## Nutzung

`mojo` ist im Build-/Dev-Image **direkt im PATH** verfügbar
(`/opt/mojo/.pixi/envs/default/bin`) — **kein `pixi run` nötig**. Du kannst das
Binary direkt aufrufen und im Container kompilieren:

```bash
# Version zeigen (auch der CMD-`docker run` ohne Argumente zeigt die Version):
docker run --rm ghcr.io/lukaslow/mojo:1.0.0 mojo --version

# Im Container kompilieren und ausführen:
docker run --rm -it ghcr.io/lukaslow/mojo:1.0.0 bash
#   $ echo 'def main(): print("hi")' > hi.mojo
#   $ mojo build hi.mojo -o hi
#   $ ./hi
```

## Tags

Die Version kommt aus der zentralen `VERSION`-Datei (aktuell `1.0.0`). Pro Version
werden zwei Images mit je drei Tags gepusht:

| Quelle | Build-Tags | Runtime-Tags |
|--------|-----------|--------------|
| `VERSION = 1.0.0` | `1.0.0`, `1.0`, `latest` | `1.0.0-runtime`, `1.0-runtime`, `latest-runtime` |

`latest`-Tags zeigen also immer auf die zuletzt gebaute Version.

## Version erhöhen

1. `VERSION`-Datei ändern (z.B. `1.0.0` → `1.0.1`).
2. Auf `main` pushen.
3. CI baut beide Images (arm64 + amd64) und pusht sie nach GHCR.

**Alte Versionen bleiben bestehen** — ein neuer Versionseintrag überschreibt keine
bestehenden Tags, sondern fügt neue hinzu. Rollbacks sind damit jederzeit möglich.

## Multi-Arch

Beide Images werden per `docker buildx` für `linux/arm64` **und** `linux/amd64`
gebaut und als Multi-Arch-Manifest gepusht. Das passiert in der CI
(`.github/workflows/ci.yml`).

Der lokale `scripts/build.sh` baut dagegen nur die **native** Plattform (`--load`),
weil `docker buildx --load` keine Multi-Platform-Builds in den lokalen Daemon
laden kann. Push übernimmt ausschließlich die CI.

## Basis-Entscheidung: debian:bookworm-slim

Beide Images basieren auf `debian:bookworm-slim` (glibc). **Nicht alpine:**

- pixi/conda-Pakete sind **glibc-basiert** und brechen unter alpine (musl libc).
- Mojo wird über den Conda-Channel `https://conda.modular.com/max/` installiert;
  dessen Binaries erwarten glibc.
- Debian bookworm-slim ist bereits schlank (glibc enthalten, keine Redundanz).

Das Build-Image installiert zusätzlich `gcc` + `libc6-dev`, weil der Mojo-Compiler
beim Linken einen C-Compiler braucht (im Benchmark-Repo verifiziert).

## Runtime-Image und der zirkuläre Bezug

Das Runtime-Image holt sich die komplette pixi-Environment aus dem Build-Image
(`COPY --from=libs /opt/mojo/.pixi ...`). Das Mojo-Binary ist **nicht statisch** —
es linkt gegen Libraries aus der pixi-Umgebung (z.B. `libKGENCompilerRTShared`),
weshalb die volle `.pixi`-Umgebung mitkopiert wird (`LD_LIBRARY_PATH` gesetzt).

**Konsequenz:** Das Runtime-Image kann erst gebaut werden, nachdem das Build-Image
existiert (und gepusht ist). Die CI baut deshalb sequentiell: erst `build`,
dann `runtime`. Das ist Absicht — so gibt es nur eine Stelle für die Toolchain
statt einer duplizierten pixi-Installation.

## Registry

Registry: **`ghcr.io/lukaslow/mojo`** (GitHub Container Registry).

CI-Trigger: Push auf `main` (oder manuell via `workflow_dispatch`).
