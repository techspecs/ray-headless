# Ray headless - container guide

Ray's on-device **subtitle & transcription engine** in a container - the same `/v4` Developer API the desktop app serves (`/v1` remains as a permanent alias), without a GUI. Generate, translate, retime and burn-in subtitles locally (or via Ray Cloud), with a built-in web dashboard.

## Which image should I use?

1. **What GPU is in the machine?** NVIDIA → `cuda`, AMD/Intel → `vulkan`, none → `cpu`.
2. **NVIDIA?** The `cuda` image runs fully on the GPU on a Linux host **and** on Windows/Docker Desktop (WSL2). **AMD/Intel?** GPU acceleration in Docker needs a **Linux** host; on Windows/macOS Docker Desktop the `vulkan`/`cpu` images run on CPU - use the desktop app if you want GPU there.

So: **NVIDIA → `cuda`** (Linux or Windows/Docker Desktop) · **Linux + AMD/Intel → `vulkan`** · **anything else → `cpu`**.

| Your hardware | Image | Run with |
|---|---|---|
| **NVIDIA GPU** (Turing / RTX 20-series and newer) | `techspecs/ray:cuda` | `--gpus all` - full GPU acceleration on a Linux host (NVIDIA Container Toolkit) **and** on Windows/Docker Desktop via WSL2 |
| **AMD or Intel GPU** | `techspecs/ray:vulkan` | `--device /dev/dri` (Linux host) |
| **No GPU / not sure** | `techspecs/ray:cpu` | *(nothing special)* |

The **cpu** and **vulkan** images run the full pipeline on CPU when no GPU is present - GPU is acceleration, not a requirement. The **cuda** image links the NVIDIA runtime and **requires `--gpus all` to start** (for a CPU-only host, use `cpu` or `vulkan`).

*Telemetry:* crash reporting is on by default (self-hosted Sentry); set `RAY_TELEMETRY=off` to disable.

## Quick start

```sh
docker volume create ray-config
docker volume create ray-models
docker volume create ray-data

# 1) Sign in once (emailed one-time code) - stored on the ray-config volume.
docker run -it --rm -v ray-config:/config techspecs/ray:cuda login

# 2) Start serving. On first boot the server prints a generated API key in its log.
docker run -d --name ray-server --gpus all -p 8787:8787 \
    -v ray-config:/config -v ray-models:/models -v ray-data:/data \
    -v "$PWD/out:/out" -v "$PWD/media:/media:ro" \
    techspecs/ray:cuda
docker logs ray-server            # grab the printed API key (stored hashed in /config)
```

(For the `vulkan` image swap `--gpus all` for `--device /dev/dri`; for `cpu`, drop both.)

### Web dashboard

Open **`http://your-host:8787/`** in a browser. Paste the API key once, then sign in to your Ray account, drag-and-drop videos (or point at a server-side path in a mounted volume), pick languages / model / where to process, and watch jobs live. It's a single self-contained page - no CDN, works air-gapped.

### One-shot mode

```sh
docker run --rm --gpus all \
    -v ray-config:/config -v ray-models:/models -v ray-data:/data \
    -v "$PWD/out:/out" -v "$PWD/media:/media:ro" \
    techspecs/ray:cuda generate /media/movie.mkv --language es --quality best
```

### Watch-folder mode (auto-subtitle a media library)

Ray watches a folder and subtitles everything in it, plus every new file that arrives. The language is required (Ray never guesses the target).

Run a dedicated watch container:

```sh
docker run -d --name ray-watch \
    -v ray-config:/config -v ray-models:/models -v ray-data:/data \
    -v /srv/media:/media \
    techspecs/ray:cpu watch /media --lang en
```

(Add `--gpus all` with `techspecs/ray:cuda`, or `--device /dev/dri` with `:vulkan`, to use a GPU.)

Or turn on watch mode on the main server container with environment variables - it keeps serving the dashboard/API and watches at the same time:

```sh
-e RAY_WATCH_DIRS=/media -e RAY_WATCH_LANGS=en
```

**Also translate or re-time?** Add `--watch-tasks` (comma-separated) from `create` (default - make subtitles), `translate`, `sync` (re-time), `submerge` - e.g. `watch /media --lang nl --watch-tasks create,translate`. For several folders with different settings, set `RAY_WATCH_CONFIG` to a JSON array, e.g. `[{"dir":"/media","languages":["nl"],"tasks":["create","translate"]}]`.

## Volumes

| Mount | Purpose |
|---|---|
| `/config` | Identity + settings - **this is your seat** (sign-in credential, API-key hashes). Persist it. |
| `/models` | Downloaded models (content-addressed cache, multi-GB). Keep it so restarts are warm. |
| `/data` | Working data + downloaded runtime components. |
| `/out` | Completed job results. |

Media to subtitle is mounted (read-only is fine) and submitted by its **in-container** path.

## Notes

- **Seat:** one container = one seat. Sign in with `login`, or set `RAY_ACCOUNT_EMAIL` + `RAY_ACCOUNT_LICENSE_KEY`.
- **Cold start:** the image ships the engine, not the models - the first job downloads what it needs into `/models` (multiple GB). Progress shows in `docker logs` and the dashboard.
- **Exposure:** the server binds loopback unless you set `RAY_DEVAPI_EXPOSE=1` **and** at least one API key exists - an exposed keyless endpoint is refused. Import a key at startup with `RAY_DEVAPI_KEY_HASH`.
- **TLS:** the server speaks plain HTTP on 8787 - put it behind your reverse proxy (Caddy/nginx/Traefik) and bind the port to localhost.
- **Telemetry:** on by default; `RAY_TELEMETRY=off` disables it.

## Tags

- `techspecs/ray:cuda`, `techspecs/ray:vulkan`, `techspecs/ray:cpu` - moving latest per variant.
- `techspecs/ray:<version>-<variant>` (e.g. `4.0.15-beta.1-cuda`) - immutable, digest-pinnable.
