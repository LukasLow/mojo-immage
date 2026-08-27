# Task: mojo-image-repo — Repo-Dateien (mojo-immage)

## Goal

Ein Git-Repo mit zwei Docker-Images für Mojo 1.0 (Modular, CLI `mojo`) bereitstellen:

1. **build** (`1.0.0` / `1.0` / `latest`) — Dev-Image mit voller Mojo-Toolchain (pixi).
2. **runtime** (`1.0.0-runtime` / `1.0-runtime` / `latest-runtime`) — schlankes Runtime-Image (debian:bookworm-slim).

Registry: `ghcr.io/lukaslow/mojo`. Version aus zentraler `VERSION`-Datei (`1.0.0`).
CI (GitHub Actions): Push auf main → beide Images arm64+amd64 bauen + nach GHCR pushen.
Alte Versionen bleiben bestehen.

## Kontext

- Arbeitsverzeichnis: `/Users/lukas/home/repos/mojo-immage` (git init, Branch main, README + .gitignore vorhanden).
- Referenz für pixi/mojo-Pfade: Benchmark-Repo `/Users/lukas/home/tmp/mojo/mojo/Dockerfile` (funktionierender Build, Exit 0).
- pixi-Env-Pfad: `/opt/mojo/.pixi/envs/default/{bin,lib}`; pixi-Bin unter `/root/.pixi/bin`.
- Docker/pixi/mojo sind hier NICHT installiert (laufen auf Host/smd nicht) → sorgfältig nach Wissensstand schreiben.

## Erstellte Dateien

- `VERSION` — `1.0.0`
- `Dockerfile` — Build/Dev-Image (debian:bookworm-slim, pixi, Mojo, gcc/libc6-dev)
- `runtime/Dockerfile` — Runtime-Image (COPY --from=libs, LD_LIBRARY_PATH)
- `examples/hello.mojo` — `def main(): print("hello from mojo")` (v1-Syntax)
- `examples/Dockerfile` — Beispiel-Multi-Stage-App (User-Workflow)
- `scripts/build.sh` — lokaler Dev-Build (native Arch, --load, kein Push)
- `.github/workflows/ci.yml` — CI: checkout, qemu, buildx, GHCR-Login, build→runtime sequentiell, multi-arch push
- `README.md` — voll ausgebaut
- `.agents/tasks/mojo-image-repo/main.md` — dieses Dokument

## Status

- **Erstellt (Dateien fertig geschrieben).**
- **Noch offen:** Build+Test (shell-Agent, docker auf Host), dann Commit/Push.

## Wer macht was (nächste Schritte)

- **coder** (ich): Dateien geschrieben — fertig.
- **shell**: `docker buildx build` lokal testen (native Arch), `examples` bauen + `docker run` → erwartet "hello from mojo".
- **shell**: Commit + Push (nach Review durch reviewer).

## Entscheidungen / Begründungen

- **Basis debian:bookworm-slim** statt alpine: pixi/conda ist glibc-basiert, musl bricht.
- **Runtime hängt am Build-Image** (COPY --from=libs) statt eigener pixi-Installation:
  weniger Duplikation, ein Ort für die Toolchain. Konsequenz: CI baut sequentiell
  (build zuerst, dann runtime).
- **pixi.toml per heredoc im RUN** generiert (nutzt ARG-Version), kein COPY → Caching
  bricht nicht; Version lebt nur im Dockerfile-ARG.
- **Versionssyntax in pixi.toml:** `mojo = ">=${MOJO_VERSION},<2"` statt exakt `==`
  → robuster (erlaubt patch/revision-Updates der Conda-Builds innerhalb der Major-Version).
- **CMD `mojo --version`** (kein ENTRYPOINT) → `docker run` ohne Args zeigt die Version.
- **scripts/build.sh = nur lokaler Dev-Build** (native Arch, --load); Push/multi-arch
  übernimmt ausschließlich die CI (docker/build-push-action). Kein separates push.sh.

## Unsicherheiten

- **pixi-Versionssyntax**: `>=${V},<2` gewählt — exakte Syntax (`==1.0.0` vs `1.0.0`)
  ist im Repo nicht verifizierbar (pixi nicht installiert). `>=,<2` ist der sichere
  Weg und erlaubt Conda-Revisions innerhalb 1.x. Falls Modular eine exakte Pin will,
  auf `==${V}` umstellen.
- **Channel `conda.modular.com/max/`** und Plattform-Namen (`linux-64`, `linux-aarch64`)
  aus dem Benchmark-Repo übernommen (dort erfolgreich) — aber nicht hier verifiziert.
- **runtime .pixi-Größe** (~1GB): bewusst gewählt (Option A), da exakte .so-Liste
  unbekannt. Kompletter .pixi-Transfer ist der verifizierte funktionierende Weg.
- **Heredoc-Versionierung**: `RUN cat > pixi.toml <<EOF && pixi install` mit unquotiertem
  Delimiter (expandiert ARG) — Shell-korrekt, aber nicht per Docker getestet.
- **Tags major.minor** via `VERSION_MAJOR_MINOR=${V%.*}` (Bash-Substitution) — für
  `1.0.0` ergibt `1.0`. Passt zum gewünschten Schema.
