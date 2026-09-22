# Ray headless

Run **Ray's on-device subtitle & transcription engine** as a server — the same `/v4` Developer API the desktop app serves (`/v1` stays as a permanent alias), without a GUI. Generate, translate, retime, narrate and burn-in subtitles locally (or via Ray Cloud), with a built-in web dashboard. Ship it as a **Docker container** or a **standalone CLI** (`ray-server` + `ray-cli`).

- 🐳 **Docker:** [`techspecs/ray`](https://hub.docker.com/r/techspecs/ray) — `cpu` / `cuda` / `vulkan`
- 💻 **CLI:** one-line installer · Homebrew · Scoop · winget · direct download (below)
- 🌐 **Site:** https://rayplayer.com
- 🐛 **Issues:** please report bugs and requests in the [Issues](../../issues) tab

> **Beta.** This is an early public release — please try it and open an issue if something breaks.

---

## Run with Docker

### Which image? Two questions

1. **What GPU is in the machine?** NVIDIA → `cuda`, AMD/Intel → `vulkan`, none → `cpu`.
2. **NVIDIA?** The `cuda` image runs fully on the GPU on a **Linux host and on Windows/Docker Desktop** (WSL2). **AMD/Intel** GPU acceleration needs a **Linux** host; on Windows/macOS Docker Desktop use `cpu` (or the desktop app if you want GPU there).

**NVIDIA → `cuda` (Linux or Windows/Docker Desktop) · Linux + AMD/Intel → `vulkan` · anything else → `cpu`.**

| Situation | Image | Run flag |
|---|---|---|
| NVIDIA (Linux **or** Windows/Docker Desktop) | `techspecs/ray:cuda` | `--gpus all` (needs NVIDIA Container Toolkit) |
| Linux + AMD / Intel | `techspecs/ray:vulkan` | `--device /dev/dri` |
| No GPU (any OS) | `techspecs/ray:cpu` | *(none)* |

The **cpu** and **vulkan** images run the full pipeline on CPU when no GPU is present. The **cuda** image links the NVIDIA runtime and **requires `--gpus all` to start** — use `cpu`/`vulkan` for a CPU-only host.

### Quick start

```sh
docker volume create ray-config
docker volume create ray-models
docker volume create ray-data

# 1) Sign in once (emailed one-time code) — stored on the ray-config volume.
docker run -it --rm -v ray-config:/config techspecs/ray:cuda login

# 2) Start serving. The server prints a generated API key in its log on first boot.
docker run -d --name ray --gpus all -p 8787:8787 \
    -v ray-config:/config -v ray-models:/models -v ray-data:/data \
    -v "$PWD/out:/out" -v "$PWD/media:/media:ro" \
    techspecs/ray:cuda
docker logs ray            # grab the printed API key (stored hashed in /config)
```

(Swap `--gpus all` for `--device /dev/dri` on the `vulkan` image; drop both on `cpu`.)

Then open **`http://your-host:8787/`** — a built-in dashboard to sign in, drag-and-drop videos, pick languages, and watch jobs live. There's also a one-shot `generate` mode and an automatic **watch-folder** mode. The first job downloads the models it needs into `/models` (multiple GB); keep that volume so restarts are warm.

**Full container docs:** [docs/docker.md](docs/docker.md) — volumes, one-shot & watch-folder modes, tags, env vars, TLS. Also mirrored on the [Docker Hub page](https://hub.docker.com/r/techspecs/ray).

---

## Install the CLI

### One-line install (recommended)

Downloads the right `ray-cli` build for your OS, verifies its checksum against `SHA256SUMS`, installs it, and adds it to your PATH.

**Linux / macOS:**
```sh
curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex
```

Open a new terminal afterwards (or follow the printed line) so the `ray-cli` command is on your PATH. Prebuilt `ray-cli` targets: Linux x64, macOS arm64, Windows x64.

### Package managers

**Homebrew (macOS / Linuxbrew):**
```sh
brew tap techspecs/ray-headless https://github.com/techspecs/ray-headless.git
brew install techspecs/ray-headless/ray-headless
```

**Scoop (Windows):**
```sh
scoop bucket add ray https://github.com/techspecs/ray-headless
scoop install ray-headless
```

**winget (Windows):**
```sh
winget install TechSpecs.RayHeadless
```

### Direct download

Grab a bundle from the [Releases](../../releases) page (Linux `.tar.gz` / `.deb` / `.AppImage`, Windows `.zip`, macOS `.pkg`).

First run needs a one-time `ray login`.

---

## Notes

- **Seat:** one container/install = one seat. Sign in with `login`, or set `RAY_ACCOUNT_EMAIL` + `RAY_ACCOUNT_LICENSE_KEY`.
- **GPU in Docker:** the NVIDIA `cuda` image uses the GPU on a **Linux host and on Windows/Docker Desktop** (WSL2). AMD/Intel (`vulkan`) needs a Linux host; on Windows/macOS without NVIDIA the images run on CPU.
- **Telemetry:** crash reporting is on by default (self-hosted Sentry). Set `RAY_TELEMETRY=off` to disable.
- **License:** Ray is proprietary software. © 2026 TechSpecs. All rights reserved. This repository holds distribution manifests and documentation, not source code.
