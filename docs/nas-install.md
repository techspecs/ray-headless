# Ray headless on a NAS - step by step

A plain-English guide to running Ray on a NAS (Synology, QNAP, Unraid, TrueNAS) or any always-on box. If you can install an app on your NAS, you can do this. No prior Docker knowledge needed.

## What you'll need

- A NAS or server that can run **Docker** (containers). Most modern NAS boxes can.
- About **5-10 GB of free space** for the models Ray downloads the first time.
- Your **Ray account** (the same sign-in you use in the desktop app).
- Your NAS's **IP address** on your network (e.g. `192.168.1.50`). You'll open `http://THAT-IP:8787/` in a browser.

> Most NAS boxes have no graphics card Ray can use, so this guide uses the **`cpu`** image, which works on everything. Have an NVIDIA GPU in the box? See [GPU acceleration](#gpu-acceleration) at the end.

---

## The easy way - Docker Compose (works on any NAS)

This is the most reliable method and it's the same on every platform.

**1. Make a folder for Ray** on your NAS, e.g. `docker/ray`.

**2. Create a file called `compose.yaml`** in that folder with this content:

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

Put the videos you want to subtitle into a `media` subfolder next to this file; finished files will appear in an `out` subfolder.

**3. Start it.** In a terminal in that folder:

```sh
docker compose up -d
```

**4. Get your API key** (the server prints one the first time it starts):

```sh
docker compose logs ray-server
```

Look for a line with a key that starts with `ray_…` and copy it.

**5. Open the dashboard.** In a browser go to:

```
http://YOUR-NAS-IP:8787/
```

Paste the API key, sign in to your Ray account, drag in a video, and pick your language. Done.

---

## Synology (DSM 7.2+ - Container Manager)

1. Open **Container Manager** → **Project** → **Create**.
2. **Project name:** `ray`. **Path:** pick/make a folder like `/docker/ray`.
3. **Source:** choose *Create docker-compose.yml* and paste the same `compose.yaml` from above.
4. Click **Next** → **Done**. Container Manager builds and starts it.
5. In Container Manager → **Container** → `ray-server` → **Details → Log**, find the `ray_…` API key.
6. Open `http://YOUR-SYNOLOGY-IP:8787/`, paste the key, sign in.

> Older DSM without "Project"? Use Container Manager → **Registry**, search **`techspecs/ray`**, download the **`cpu`** tag, then create a container: map port **8787**, add the four folder mounts (`/config`, `/models`, `/data`, `/out`, `/media`), and add environment variable `RAY_DEVAPI_EXPOSE=1`.

---

## Unraid

1. **Apps** (Community Applications) → search **Ray** - or add a container manually with **Add Container**.
2. **Repository:** `techspecs/ray:cpu`
3. **Port:** add `8787` → `8787`.
4. **Volumes (Paths):** map host folders to `/config`, `/models`, `/data`, `/out`, and your media share to `/media` (read-only).
5. **Variables:** add `RAY_DEVAPI_EXPOSE` = `1`.
6. **Apply.** Then open the container **Log** to copy the `ray_…` key, and browse to `http://YOUR-UNRAID-IP:8787/`.

---

## QNAP (Container Station)

1. **Container Station** → **Create** → **Create Application**, and paste the `compose.yaml` from above, **or** search the image `techspecs/ray` and create a container.
2. Map port **8787**, add the `/config` `/models` `/data` `/out` `/media` folders, and set `RAY_DEVAPI_EXPOSE=1`.
3. Start it, open the container **logs** for the `ray_…` key, then visit `http://YOUR-QNAP-IP:8787/`.

---

## First use

- **Sign in:** on the dashboard, paste the API key once, then sign in to your Ray account (a one-time email code).
- **Subtitle a video:** drag-and-drop a file, or point Ray at a file already inside your mounted `media` folder, choose the language, and start. Watch progress live.
- **Where results go:** finished subtitle files appear in the `out` folder you mapped.
- **Auto-subtitle a whole library:** see watch-folder mode in [docs/docker.md](docker.md).

---

## Where your data lives (and what to keep)

| Folder inside the container | What it is | Keep it? |
|---|---|---|
| `/config` | your sign-in + settings | **Yes** - deleting it logs you out |
| `/models` | downloaded models (several GB) | **Yes** - deleting it re-downloads everything |
| `/data` | working data | yes |
| `/out` | finished results | that's your output |
| `/media` | your source videos (read-only) | your files |

---

## Using a different port

Ray uses port **8787**. If something else on your machine is already using it (you'll get a `port is already allocated` error), or you just want a different one, it's a one-number change.

The port setting is written as **`HOST:CONTAINER`** - two numbers with a colon:

- The **first** number is the port **on your machine**. **This is the one you change.**
- The **second** number is the port **inside the container**. **Always leave it `8787`.**

Example - to use `8080` instead of `8787`:

- **Compose:** change the ports line to `- "8080:8787"`
- **`docker run`:** use `-p 8080:8787`

Then open **`http://YOUR-NAS-IP:8080/`** in your browser - use your new number in the address too. Nothing else needs to change.

---

## Troubleshooting

- **`driver failed programming external connectivity` / `port is already allocated`.** Port `8787` is already in use on your machine, so Ray can't grab it. Easiest fix: **[use a different port](#using-a-different-port)** (change only the first number). To instead free up 8787: remove any old container with `docker rm -f ray-server`, then find what's holding the port - Linux/NAS: `sudo ss -ltnp | grep 8787`; Windows: `netstat -ano | findstr 8787`. On Windows/Docker Desktop, if the port sits in Windows' reserved range, run `net stop winnat` then `net start winnat` in an admin PowerShell, or just restart Docker Desktop.
- **Page won't load at `http://NAS-IP:8787/`.** Make sure the container is running, the port `8787` is mapped, and `RAY_DEVAPI_EXPOSE=1` is set (without it, the server only answers on the NAS itself, not from other devices). Check your NAS firewall allows port 8787.
- **It asks for an API key and I don't have one.** The key is printed in the container's **log** the first time it starts (`docker compose logs ray-server`). Copy the `ray_…` value.
- **First subtitle job sits at "downloading".** The first run pulls the models it needs (several GB) into `/models`. That's a one-time download - later jobs start immediately. Keep the `models` volume.
- **"No space left" / stuck downloads.** Make sure the volume that holds `/models` has several GB free.
- **Permissions on the media/out folders.** If Ray can't read your videos or write results, check the folder permissions on the NAS so the container can access them.

---

## GPU acceleration

The `cpu` image works everywhere and needs no special setup. If your box has a supported GPU and you want faster processing:

- **NVIDIA:** use `techspecs/ray:cuda` and pass the GPU through (in Compose, add the `deploy.resources.reservations.devices` GPU block; on Unraid/DSM enable NVIDIA runtime and add `--gpus all`). Works on a Linux host and on Windows/Docker Desktop.
- **AMD / Intel (Linux host):** use `techspecs/ray:vulkan` and pass `--device /dev/dri`.

Everything still runs fine on CPU if you skip this - the GPU only makes it faster.
