# Ray headless

Run **Ray's subtitle & transcription engine** as a server - same as the desktop app, no GUI, driven by a `/v4` Developer API (`/v1` is a permanent alias) plus a built-in web dashboard. Runs as a **Docker container** or a **standalone CLI** (`ray-server` + `ray-cli`). Perfect for a home server, NAS, or media library.

- 🐳 **Docker:** [`techspecs/ray`](https://hub.docker.com/r/techspecs/ray) - `cpu` / `cuda` / `vulkan`
- 💻 **CLI:** one-line installer · Homebrew · Scoop · winget · direct download
- 📟 **On a NAS?** Follow the step-by-step [**NAS install guide**](docs/nas-install.md) (Synology / Unraid / QNAP).
- 🌐 **Site:** https://rayplayer.com  ·  🐛 **Issues:** [Issues tab](../../issues)

> **Beta** - early public release. Please try it and open an issue if something breaks.

---

## Get running in 3 steps

No GPU required - this uses the `cpu` image, which runs on any machine with Docker. (Want it faster on a GPU box? See [GPU acceleration](#gpu-acceleration).)

**1. Start the server:**

```sh
docker run -d --name ray-server -p 8787:8787 \
  -e RAY_DEVAPI_EXPOSE=1 \
  -v ray-config:/config -v ray-models:/models -v ray-data:/data \
  -v "$PWD/out:/out" -v "$PWD/media:/media:ro" \
  techspecs/ray:cpu
```

**2. Copy your API key** (the server prints one on first start):

```sh
docker logs ray-server
```

Look for a line with a key starting `ray_…` and copy it.

**3. Open the dashboard** in a browser:

```
http://SERVER-IP:8787/
```

Paste the key, sign in to your Ray account, and drag in a video. Done.

> Replace `SERVER-IP` with the machine's address - `localhost` if it's your own computer, or your server/NAS IP like `192.168.1.50`.
> The first job downloads the models it needs (a few GB) into the `ray-models` volume; every run after that starts instantly.
>
> **Got `driver failed programming external connectivity` / `port is already allocated`?** Port 8787 is already in use. Change only the **first** number of `-p 8787:8787` to any free port (e.g. `-p 8080:8787`) and open that port in the browser. Details: [using a different port](docs/nas-install.md#using-a-different-port).

---

## Easiest for a NAS or always-on server: Docker Compose

Save this as `compose.yaml`, put your videos in a `media` folder beside it, then run `docker compose up -d`:

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    container_name: ray-server
    ports:
      - "8787:8787"
    environment:
      RAY_DEVAPI_EXPOSE: "1"
    volumes:
      - ray-config:/config
      - ray-models:/models
      - ray-data:/data
      - ./out:/out
      - ./media:/media:ro
    restart: unless-stopped

volumes:
  ray-config:
  ray-models:
  ray-data:
```

```sh
docker compose up -d
docker compose logs ray-server     # copy the printed ray_… API key
```

Then open **`http://SERVER-IP:8787/`** and paste the key.
**Full NAS walkthrough** (Synology Container Manager, Unraid, QNAP, troubleshooting): [**docs/nas-install.md**](docs/nas-install.md).

---

## GPU acceleration

The `cpu` image works everywhere. For faster processing on a machine with a GPU, use the matching image (swap the image name, and add the flag, in the commands above):

| Your hardware | Image | Extra flag |
|---|---|---|
| **NVIDIA GPU** (Linux, or Windows/Docker Desktop) | `techspecs/ray:cuda` | `--gpus all` (Linux needs the NVIDIA Container Toolkit) |
| **AMD / Intel GPU** (Linux host) | `techspecs/ray:vulkan` | `--device /dev/dri` |
| **No GPU / not sure** | `techspecs/ray:cpu` | *(none)* |

The `cuda` image **requires `--gpus all`** to start; use `cpu`/`vulkan` on a machine without an NVIDIA GPU.

---

## Install the CLI

### One-line install (recommended)

Downloads the right `ray-cli` build for your OS, verifies its checksum, and adds it to your PATH.

**Linux / macOS:**
```sh
curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex
```

Open a new terminal afterwards so `ray-cli` is on your PATH.

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

---

## Using it

- **Web dashboard** (`http://SERVER-IP:8787/`): drag-and-drop videos, pick languages, watch progress live; finished files land in your `out` folder.
- **One-shot from the command line** and **watch-folder** mode (auto-subtitle a whole library): see [**docs/docker.md**](docs/docker.md).

---

## Notes

- **Your seat:** one container = one seat. Sign in from the dashboard, or set `RAY_ACCOUNT_EMAIL` + `RAY_ACCOUNT_LICENSE_KEY`.
- **Keep your volumes:** `ray-config` holds your sign-in; `ray-models` holds the downloaded models. Deleting them means re-logging-in / re-downloading.
- **Access from other devices:** `RAY_DEVAPI_EXPOSE=1` lets other machines on your network reach it (an API key is required - the server creates one on first boot and prints it to the log).
- **TLS:** the server speaks plain HTTP on 8787 - put it behind a reverse proxy (Caddy / nginx / Traefik) for HTTPS.
- **Telemetry:** on by default; set `RAY_TELEMETRY=off` to disable.
- **Full container reference:** [docs/docker.md](docs/docker.md).
- **License:** Ray is proprietary software. © 2026 TechSpecs. All rights reserved. This repository holds distribution manifests and documentation, not source code.
