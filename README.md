# Ray headless

Run **Ray's subtitle server** on a NAS, home server or any always-on box - the same Ray as the desktop app, without the desktop. A built-in web dashboard and a Developer API make, translate, re-time and burn in subtitles on your own hardware (Ray Local) or on Ray's servers (Ray Cloud). Runs in **Docker** or **straight on Linux, macOS or Windows**, no Docker needed (`ray-server` + `ray-cli`).

- 🐳 **Docker:** [`techspecs/ray`](https://hub.docker.com/r/techspecs/ray) - `cpu` / `cuda` / `vulkan`
- 🖥️ **No Docker?** Install the server itself on Linux, macOS or Windows: one-line installer · Homebrew · Scoop · Chocolatey · download - [**Run the server without Docker**](#run-the-server-without-docker).
- 📟 **On a NAS?** Follow the step-by-step [**NAS install guide**](docs/nas-install.md) (Synology / Unraid / QNAP / TrueNAS).
- 📖 **Everything else:** the [**container guide**](docs/docker.md).
- 🔌 **MCP:** let Cursor and other apps that speak the Model Context Protocol make, translate and read subtitles on your server - the [**MCP guide**](docs/mcp.md).
- 💻 **Just the command line:** `ray-cli` on its own, for a Ray server that runs somewhere else - [Install only the CLI](#install-only-the-cli).
- 🌐 **Site:** https://rayplayer.com  ·  🐛 **Issues:** [Issues tab](../../issues)

> **Beta** - please try it and open an issue if something breaks.

## What it does

- **Subtitles next to your videos** - saved as `Movie.en.srt` right beside `Movie.mkv`, where Plex, Jellyfin and Emby find them. Never replaces a subtitle it didn't make.
- **Watch folders** - add a folder in the dashboard and every video in it (and every new one) gets subtitles. No restart, no config files.
- **Sonarr and Radarr** - every new episode and movie gets subtitles the moment it's imported; renames, upgrades and deletes are followed.
- **A private dashboard for the whole household** - everyone gets their own access; owners manage the server, members add and follow their own jobs.
- **Browse the server's folders** - pick folders and videos on the server from the dashboard instead of copying paths, with favorite folders and what each member may use.
- **The right audio track** - pick the track for anime with an English dub or films with commentary, or set a preferred audio language.
- **Ray Cloud when you want it** - per job, per folder, or only when the NAS can't do it itself.
- **Your PC's graphics card** - the NAS can send the work to Ray on your computers and get the subtitles back.
- **Runs as your NAS user** - `PUID` / `PGID` / `UMASK`, so the files belong to you.

---

## Get running in 3 steps

No graphics card needed - this uses the `cpu` image, which runs on any computer with Docker and a 64-bit Intel or AMD processor. The images don't run on ARM, such as a Raspberry Pi or a NAS with an ARM processor; on a Mac with Apple silicon, [run the server without Docker](#run-the-server-without-docker) instead. (NVIDIA or AMD card? See [Pick your image](#pick-your-image). No Docker? See [Run the server without Docker](#run-the-server-without-docker).)

**1. Start the server.** First make a folder for Ray with a `media` folder inside it, and put your videos (or a test video) in `media`. Then open a terminal in the Ray folder and run the command there: `$PWD` is the folder you're in, so Ray reads videos from `media` and saves finished subtitles to an `out` folder next to it.

```sh
docker run -d --name ray-server --restart unless-stopped \
  -p 8787:8787 \
  -e PUID=1000 -e PGID=1000 \
  -v ray-config:/config -v ray-models:/models -v ray-data:/data \
  -v "$PWD/out:/out" -v "$PWD/media:/media" \
  techspecs/ray:cpu
```

On Windows (Docker Desktop), in PowerShell, the lines end with a backtick instead of `\`:

```powershell
docker run -d --name ray-server --restart unless-stopped `
  -p 8787:8787 `
  -e PUID=1000 -e PGID=1000 `
  -v ray-config:/config -v ray-models:/models -v ray-data:/data `
  -v "$PWD/out:/out" -v "$PWD/media:/media" `
  techspecs/ray:cpu
```

On a NAS, set `PUID` / `PGID` to your own user (run `id` - see the [NAS guide](docs/nas-install.md#step-2---find-your-user-id-puid-and-pgid)).

**2. Open the dashboard** in a browser:

```
http://SERVER-IP:8787/
```

> `SERVER-IP` is `localhost` on your own computer, or the server's address like `192.168.1.50`.
> Port 8787 taken (`port is already allocated`)? Change only the **first** number: `-p 8080:8787`, then open port 8080. Details: [using a different port](docs/nas-install.md#using-a-different-port).

**3. Sign in and connect your Ray account.**

1. **Copy the key.** At its first start the server printed an owner key in its log, in a box between two lines of `=====`. To show just that part:

   ```sh
   docker logs ray-server 2>&1 | grep -A3 "generated an API key"
   ```

   On Windows (Docker Desktop), in PowerShell: `docker logs ray-server 2>$null | Select-String "generated an API key" -Context 0,3`, or in Docker Desktop: **Containers** > `ray-server` > **Logs**. The key is the line that starts with `ray_`: copy all of it (`ray_` and 48 letters and digits). It is shown only this once and stored hashed, so Ray can't show it again. Lost it? See [Lost the key](docs/docker.md#lost-the-key).
2. **Sign in.** The page says **Set up this Ray server**. Paste the key into the field that says **Paste your API key**. On a computer you share, untick **Keep me signed in on this browser** (under the button). Then choose **Sign in**. A message says **Signed in. Now connect this server to your Ray account.** If a short tour opens, choose **Show me around** or **Skip tour**.
3. **Connect your Ray account.** On **Create**, find the card **This server's Ray account** and choose **Use an email code instead**. Type your Ray account's email under **Email** and choose **Send code**. Type the 6-digit code from the email under **Code from the email** and choose **Verify**. If your email can use more than one Ray account, the window says **Choose a Ray account**: choose the one this server should use (yours is **My own Ray account**).
4. **Check that it worked.** A message at the top right says **Connected this server to** your email, and the card **This server's Ray account** shows **Connected to** with your email, partly hidden.

With Ray on your Windows PC or Mac, step 3 also works without an email: choose **Connect with your Ray app**, pick your computer, choose **Approve sign-in** on it, then **Connect**. On Docker's default network that works only once `RAY_NEARBY_LAN_SUBNETS` is set: see [The computer isn't listed?](docs/docker.md#the-computer-isnt-listed)

Rather approve on Ray on your computer than paste a key? **Sign in with your Ray app** is off until you turn it on at the top of **People** (or set `RAY_APP_SIGNIN=on`). It needs Ray 4.0.16 or later on that computer and works on the server's own network. With `RAY_APP_SIGNIN=on` from the first start, the setup screen asks for the **Key from the server log** and **Continue** instead: see [Set up a new server with the app](docs/docker.md#set-up-a-new-server-with-the-app).

Then drag in a video, or pick one under `/media`, and choose your language. Done.

> The first job downloads what Ray needs (a few GB) into the `ray-models` volume; every job after that starts right away.
> The key in the log is the **owner key**: keep it safe and don't share it. Give everyone else their own access from the dashboard's **People** tab.

---

## Easiest for a NAS or always-on server: Docker Compose

Download [`compose.yaml`](compose.yaml) into a folder (or copy it from below), set your `PUID` / `PGID` and your video folder, then run `docker compose up -d`:

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    container_name: ray-server
    ports:
      - "8787:8787"
    environment:
      PUID: "1000"      # your user id (run `id` on the NAS)
      PGID: "1000"      # your group id
      UMASK: "022"      # "002" lets your group edit the files Ray writes
    volumes:
      - ray-config:/config
      - ray-models:/models
      - ray-data:/data
      - ./out:/out
      - ./media:/media  # your videos; add :ro to keep every subtitle in ./out
    restart: unless-stopped

volumes:
  ray-config:
  ray-models:
  ray-data:
```

```sh
docker compose up -d
docker compose logs ray-server     # the key starting with ray_
```

Then open **`http://SERVER-IP:8787/`** and sign in as in [step 3 above](#get-running-in-3-steps). In the `docker compose logs` output each line starts with `ray-server` and a `|`: copy only the key, from `ray_` to the end of its line.

> `media` is mounted **read-write** so Ray can save subtitles **next to your videos** (tick **Save next to the video**; watch folders and Sonarr / Radarr do it by default). Ray never changes your videos and never replaces a subtitle it didn't make. Add `:ro` to keep every result in the `out` folder instead, named after the video (`Movie.en.srt`).

**Full NAS walkthrough** (Synology Container Manager, Unraid, QNAP, TrueNAS, Sonarr and Radarr, your PC's graphics card, troubleshooting): [**docs/nas-install.md**](docs/nas-install.md).

---

## Pick your image

| Your hardware | Image | Extra flag |
|---|---|---|
| **NVIDIA graphics card** (Linux, or Windows with Docker Desktop) | `techspecs/ray:cuda` | `--gpus all` (Linux needs the NVIDIA Container Toolkit) |
| **Separate AMD graphics card** (Linux host) | `techspecs/ray:vulkan` | `--device /dev/dri --device /dev/kfd` |
| **Integrated graphics** (most NAS boxes and mini PCs), **Intel graphics**, **no graphics card**, or **not sure** | `techspecs/ray:cpu` | *(none)* |

The `cuda` image **requires `--gpus all`** to start. Ray Local doesn't use integrated or Intel graphics, so `cpu` is the right image there. No graphics card, but a PC with one next to the NAS? Let the server [use your devices](docs/docker.md#use-your-devices-nearby-processing).

---

## Run the server without Docker

The same server, dashboard and `ray-cli` as the Docker image, installed straight on **Linux** (x64), **macOS** (Apple silicon) or **Windows** (x64).

**Which download is which:**

| | **Full server:** the `ray` command - `ray serve`, the dashboard and the CLI | **Client only:** `ray-cli`, no server, no dashboard |
|---|---|---|
| One-line installer | with `--server` (`-Server` on Windows) | without it ([Install only the CLI](#install-only-the-cli)) |
| Homebrew, Scoop, Chocolatey | yes | - |
| [Releases](../../releases) page | the `ray-headless` files (`.tar.gz`, `.zip`, `.deb`, `.pkg`) and `Ray-...-x86_64.AppImage` | the `ray-cli` files (`.tar.gz`, `.zip`) |

With the full server, `ray serve` starts it and `ray api ...` does everything `ray-cli` does (the one-line installer adds a `ray-cli` command too).

### Install the server

**One-line installer** - downloads the full server for your system (several hundred MB), verifies its checksum and puts the `ray` and `ray-cli` commands on your PATH:

Linux / macOS:
```sh
curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh -s -- --server
```

Windows (PowerShell):
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1))) -Server
```

Open a new terminal afterwards so `ray` is on your PATH.

**Homebrew** (macOS on Apple silicon, Linux x64):
```sh
brew tap techspecs/ray-headless https://github.com/techspecs/ray-headless.git
brew install techspecs/ray-headless/ray-headless
```

**Scoop** (Windows):
```powershell
scoop bucket add extras         # once: Microsoft's Visual C++ runtime comes from there
scoop bucket add ray https://github.com/techspecs/ray-headless
scoop install ray-headless
```

**Chocolatey** (Windows; this is a beta, so add `--pre`):
```powershell
choco install ray-headless --pre
```

**Or download it** from the [Releases](../../releases) page (`<version>` is the release, like `4.0.16`):

| File | System | Start it with |
|---|---|---|
| `ray-headless_<version>_amd64.deb` | Debian, Ubuntu | `sudo apt install ./ray-headless_<version>_amd64.deb`, then `ray serve` |
| `ray-headless-<version>.pkg` | macOS (Apple silicon) | open it to install, then `ray serve` |
| `ray-headless-linux-x64-<version>.tar.gz` | Linux | `tar xzf` it, then `./ray-headless/ray serve` |
| `Ray-<version>-x86_64.AppImage` | Linux | the same server in one file: `chmod +x` it, then `./Ray-<version>-x86_64.AppImage serve` |
| `ray-headless-macos-arm64-<version>.tar.gz` | macOS | `tar xzf` it, then `./ray-headless/ray serve` |
| `ray-headless-windows-x64-<version>.zip` | Windows | unzip it, then `.\ray.cmd serve` in the `ray-headless-windows-x64` folder |

They are large (several hundred MB): everything the server runs on is inside. What Ray needs to make subtitles (a few GB) downloads at the first job, as in Docker.

> **Linux:** needs Ubuntu 24.04, Debian 13 or newer (or another distribution as recent). The `.deb` brings in the few system packages Ray uses, and the one-line installer names any that are missing with the command that adds them. With the `.tar.gz` or the AppImage on a minimal system, add them yourself (Debian and Ubuntu: `sudo apt install libasound2t64 libvulkan1 libegl1 libgl1 libpulse0 libdbus-1-3 libgomp1 fontconfig ca-certificates`). If the AppImage says FUSE is missing, use the `.tar.gz` instead.
>
> **Windows:** Ray needs Microsoft's Visual C++ runtime, which most PCs already have. If Windows says a file like `VCRUNTIME140.dll` was not found, run `vc_redist.x64.exe` from Ray's folder once (the one-line installer tells you when).

### Start it and open the dashboard

```sh
ray serve
```

It runs in that terminal until you press Ctrl+C, and says `listening on http://127.0.0.1:8787`. Open the dashboard **on that computer**:

```
http://127.0.0.1:8787/
```

A server you install yourself has no key yet, so it opens without signing in, and only on its own computer: the dashboard says **No API keys - open on this device**. Every program on this computer can use it that way too, so on a computer you share, add a key (next step). Typing a key in the dashboard's **API key** dialog doesn't add one: while the server has no key, the dialog says a key typed there stays in that browser and protects nothing.

Connect the server to your Ray account in **This server's Ray account** on **Create** (or run `ray login` in a terminal on that computer, as the same user), so it can download what it needs and use Ray Cloud. Then drag in a video, or give a file's full path on this computer, and choose your language.

### Use it from other devices

The server stays on its own computer until it has a key: it never opens to your network without one, and its open dashboard can't make keys. Start it once with `--host 0.0.0.0`, and it makes the first **owner key** itself:

```sh
ray serve --host 0.0.0.0
```

(With the `.zip` on Windows: `.\ray.cmd serve --host 0.0.0.0` in the `ray-headless-windows-x64` folder.) It prints the key once, in that terminal, in a box between two lines of `=====`: under **Ray generated an API key for this server**, the line that starts with `ray_`. Copy all of it (`ray_` and 48 letters and digits) and keep it safe. It is shown only this once and stored hashed: Ray keeps only a fingerprint of it and never writes the key to its log file. Later starts don't show it again, and need just the same `ray serve --host 0.0.0.0`.

Then sign in from another device:

1. Open `http://COMPUTER-IP:8787/` (`COMPUTER-IP` is that computer's address, like `192.168.1.20`).
2. The page says **Set up this Ray server**, or **Sign in with an API key** when the server is already connected to a Ray account (by the Ray app on that computer, say). Paste the key into the field that says **Paste your API key**. On a computer you share, untick **Keep me signed in on this browser** (under the button). Then choose **Sign in**.
3. Not connected to a Ray account yet? On **Create**, connect it under **This server's Ray account**, as in [step 3 of Get running](#get-running-in-3-steps): **Use an email code instead**, your email, **Send code**, the code under **Code from the email**, **Verify**.
4. Give everyone else their own access from **People**.

From now on the dashboard asks for a key on this computer too, and so do `ray api` commands: store it once with `ray login ray_...`.

- Lost the key? Still signed in on a browser: in **People**, on the **Owner** row, the **⋯** button > **Replace their API key** > **Replace key** shows a new one to copy. Otherwise start the server once with a key of your own (below): the other keys and settings stay.
- `RAY_DEVAPI_EXPOSE=1` does the same as `--host 0.0.0.0`. Both count for that start only, so use one every time (see [Keep it running](#keep-it-running)).
- `RAY_DEVAPI_GENERATE_KEY=0` skips making the key: the server then stays on its own computer until you give it one (below).
- When Ray can't save its settings, the box says so: the key then works until the server stops, and the next start makes a new one (see [Settings Ray can't save](#settings-ray-cant-save)).
- Let `ray-server` through the computer's firewall if it asks.
- For HTTPS, or to reach it from outside your home, put it behind a reverse proxy (see [TLS and reverse proxies](docs/docker.md#tls-and-reverse-proxies)).

**Your own key instead.** Give the server the key's sha256 in `RAY_DEVAPI_KEY_HASH`: the hash, never the key itself. On Linux and macOS these are the lines `ray-server` prints when it won't open without a key:

```sh
RAY_KEY="ray_$(openssl rand -hex 24)"; echo "$RAY_KEY"   # keep it: this is the key you paste
export RAY_DEVAPI_KEY_HASH="$(printf '%s' "$RAY_KEY" | sha256sum | cut -d' ' -f1)"
ray serve --host 0.0.0.0
```

On a Mac, use `shasum -a 256` for `sha256sum`.

Windows (PowerShell):
```powershell
$bytes = [byte[]]::new(24); [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$key = "ray_" + -join ($bytes | ForEach-Object { $_.ToString("x2") })
$key                                                     # your owner key: keep it safe
$env:RAY_DEVAPI_KEY_HASH = -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($key)) | ForEach-Object { $_.ToString("x2") })
ray serve --host 0.0.0.0
```

- Ray keeps the fingerprint: later starts need just `ray serve --host 0.0.0.0`, without `RAY_DEVAPI_KEY_HASH`.
- While `RAY_DEVAPI_KEY_HASH` is set, the server makes no key of its own. An entry that starts with `ray_` is the key itself: the server skips it and says how to make the hash. Keep the `ray_` at the start of your key: a key of 64 hex characters put there by mistake is taken as a hash, and then that key lets nobody in.
- `RAY_API_KEY` is the `ray` command's setting: the key `ray api` and `ray-cli` send to a server. The server never reads it: when `RAY_API_KEY` is set where the server starts and isn't one of its keys, the server says so and points to `RAY_DEVAPI_KEY_HASH`.

### Keep it running

`ray serve` stops when its terminal closes. To have it start by itself:

<details>
<summary><b>Linux:</b> a systemd user service</summary>

```sh
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/ray-server.service <<EOF
[Unit]
Description=Ray server

[Service]
ExecStart=$(command -v ray) serve
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now ray-server
sudo loginctl enable-linger "$USER"      # keep it running while you're logged out
```

Add `--host 0.0.0.0` after `serve` once the server has a key (then `systemctl --user daemon-reload` and `systemctl --user restart ray-server`). `journalctl --user -u ray-server -f` shows what it's doing. With a `.tar.gz` or the AppImage, put its full path after `ExecStart=` instead.

</details>

<details>
<summary><b>macOS:</b> a LaunchAgent</summary>

```sh
cat > ~/Library/LaunchAgents/io.techspecs.ray-server.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>io.techspecs.ray-server</string>
  <key>ProgramArguments</key><array><string>$(command -v ray)</string><string>serve</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
EOF
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.techspecs.ray-server.plist
```

It starts whenever you log in. A LaunchAgent keeps none of the server's output, so get the first key in a terminal (see [Use it from other devices](#use-it-from-other-devices)). Add `<string>--host</string><string>0.0.0.0</string>` after `<string>serve</string>` once the server has a key (then `launchctl bootout gui/$(id -u)/io.techspecs.ray-server` and the `bootstrap` line again).

</details>

<details>
<summary><b>Windows:</b> your Startup folder</summary>

Press **Win+R**, type `shell:startup` and press Enter. In that folder, right-click > **New** > **Shortcut** and enter `cmd /c ray serve` (with the `.zip`, the full path of its `ray.cmd` in place of `ray`). Add `--host 0.0.0.0` once the server has a key. The server starts in its own window when you sign in to Windows; closing that window stops it.

</details>

Start it as the same user every time: Ray keeps the server's settings, keys and Ray account with the user account that runs it. Another user, `sudo ray serve` included, has its own settings, so its own keys and Ray account.

**The Ray app on the same computer?** For the same user, the server and the app share these: the same Ray account (disconnecting it in the dashboard signs the app out too), the same keys and the same saved port.

### Ports

`ray serve` listens on port 8787 unless you saved another one.

- `ray serve --port 9000` uses 9000 for that start only. Open `http://127.0.0.1:9000/`, and give `ray api` and `ray login` the same `--port 9000`.
- `ray serve --port 9000 --save-port` also saves it: later starts, and `ray api` on this computer, use 9000 by themselves (so does the Ray app on this computer). `ray serve --port 8787 --save-port` puts it back.

### Where files go

| | Linux and macOS | Windows |
|---|---|---|
| What Ray downloads to make subtitles (a few GB) | `~/.local/share/ray/models` | `%LOCALAPPDATA%\Ray\models` |
| Results | `~/.local/share/ray/out` | `%LOCALAPPDATA%\Ray\out` |
| Working data | `~/.local/share/ray/data` | `%LOCALAPPDATA%\Ray\data` |
| Settings: the keys (as fingerprints), the Ray account, the port. Shared with the Ray app on the same computer. | `~/.config/Ray/Ray.conf` on Linux, Ray's preferences on macOS | the registry, `HKCU\Software\Ray\Ray` |

- To use other folders, set `RAY_MODEL_ROOT`, `RAY_DEVAPI_RESULTS_DIR` or `RAY_LOCAL_STORAGE_ROOT` before `ray serve` (on Linux and macOS, `XDG_DATA_HOME` moves all three).
- Pick videos by their full path on that computer (`/home/you/Videos/Movie.mkv`, `D:\Videos\Movie.mkv`). **Save next to the video** works in every folder the server's user can write to.
- The first lines `ray serve` prints say where its log file is.
- The server's settings in the container guide's [environment variables](docs/docker.md#environment-variables) work here too: set them before `ray serve`. `PUID`, `PGID`, `UMASK`, `RAY_SKIP_CHOWN` and `RAY_GENERATE_PORT` belong to the container only, and `RAY_DEVAPI_EXPOSE` is off unless you set it. `ray serve --help` lists every setting, `ray help` the other commands.

### Settings Ray can't save

When the user that starts the server can read its settings but can't save them (they are on a read-only disk, or their folder belongs to another user, say), `ray serve` says so when it starts, with the fix, and the dashboard says so on **This server's Ray account**. Do what it says (give that user its settings back, or start the server as the user they belong to), then restart. Until then:

- **Works until the server stops:** your key (a key this start made works until then, and its box says the next start makes a new one), keys from `RAY_DEVAPI_KEY_HASH` (at every start, because they come from where it starts), signing in to the dashboard with a key, and a Ray account set with `RAY_ACCOUNT_EMAIL` and `RAY_ACCOUNT_LICENSE_KEY`. A key you remove in **People** stays removed, and the installation ID in **Copy diagnostics** stays the same.
- **Refused, so nothing is lost at the next start:** connecting or disconnecting the server's Ray account, **Sign in with your Ray app**, sign-in links, and new keys in **People**.
- **Lost when it restarts:** whatever changed while it ran. A key you removed comes back if it was saved before.

A settings file that exists but this user can't read (another user's file, say) is different: its keys and Ray account aren't read and no new key is made, so the server stays on its own computer and says why. Only a key in `RAY_DEVAPI_KEY_HASH` lets it open to your network until then.

### Update

Stop the server, then run the one-line installer again (with `--server`, or `-Server` on Windows), `brew upgrade ray-headless`, `scoop update ray-headless`, `choco upgrade ray-headless --pre`, or install the newer download. Settings, keys and downloads stay.

### Uninstall

Stop the server first (Ctrl+C in its terminal). Steps 1 to 3 remove Ray's program and commands; your settings, keys, downloads and results stay unless you also do step 4.

**1. Stop it starting by itself**, if you set that up in [Keep it running](#keep-it-running).

Linux:
```sh
systemctl --user disable --now ray-server 2>/dev/null
rm -f ~/.config/systemd/user/ray-server.service
systemctl --user daemon-reload
```

Turned on `loginctl enable-linger` only for Ray? `sudo loginctl disable-linger "$USER"` turns it off again.

macOS:
```sh
launchctl bootout gui/$(id -u)/io.techspecs.ray-server 2>/dev/null
rm -f ~/Library/LaunchAgents/io.techspecs.ray-server.plist
```

Windows: press **Win+R**, type `shell:startup` and press Enter, then delete the shortcut you made for `ray serve`.

**2. Free its seat (optional).** Not using the Ray app on this computer? Run `ray logout` while Ray is still installed (with a download, from its folder, as you start it there): it signs this computer out of your Ray account, which frees its seat, and forgets the stored key. With only the CLI, `ray-cli logout` forgets the key `ray-cli login` stored. With the Ray app on this computer, skip this step: the app shares that sign-in and would be signed out too.

**3. Remove the program**, the way you installed it.

**One-line installer, Linux / macOS.** Its `ray-install: installed ...` line said where it put the commands and the program's files: `~/.local/bin` and `~/.local/lib`, or `/usr/local/bin` and `/usr/local/lib` when it could write there. For the server and for the CLI on its own:

```sh
rm -f ~/.local/bin/ray-cli
rm -rf ~/.local/lib/ray-headless ~/.local/lib/ray-cli
[ -L ~/.local/bin/ray ] && [ ! -e ~/.local/bin/ray ] && rm -f ~/.local/bin/ray
```

In `/usr/local`:

```sh
sudo rm -f /usr/local/bin/ray-cli
sudo rm -rf /usr/local/lib/ray-headless /usr/local/lib/ray-cli
[ -L /usr/local/bin/ray ] && [ ! -e /usr/local/bin/ray ] && sudo rm -f /usr/local/bin/ray
```

The last line of each removes the `ray` command only once it leads nowhere (the line before took its files), so another program called `ray` stays. Chose your own folders with `--dir` or `--lib-dir`? Put the ones its `installed` line named in place of these, in all three lines. The `# Ray CLI` and `export PATH=...` lines the installer may have added to `~/.zshrc`, `~/.bashrc` or `~/.profile` do no harm; delete them if you like.

**One-line installer, Windows.** It put the server in `%LOCALAPPDATA%\Programs\Ray\headless`, the CLI on its own in `%LOCALAPPDATA%\Programs\Ray\bin`, and its folder on your user Path. In PowerShell:

```powershell
$p = "$env:LOCALAPPDATA\Programs\Ray"
if (Test-Path "$p\headless\ray-server.exe") { Remove-Item "$p\headless" -Recurse -Force }
if (Test-Path "$p\bin\ray-cli.exe") { Remove-Item "$p\bin" -Recurse -Force }
if (-not (Get-ChildItem $p -Force -ErrorAction SilentlyContinue)) { Remove-Item $p -ErrorAction SilentlyContinue }
# take only those two folders off your user Path
$key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
$old = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
$new = ($old -split ';' | Where-Object { $_ -and @("$p\headless", "$p\bin") -notcontains $_.TrimEnd('\') }) -join ';'
if ($new -ne $old) { $key.SetValue('Path', $new, 'ExpandString') }
$key.Close()
```

Then open a new terminal. The Ray app keeps its own `ray` command in another folder, `%LOCALAPPDATA%\Ray\bin` (not `Programs\Ray\bin`), with its own Path entry: these lines leave both alone.

Installed with `-Dir`? Run this instead, with that folder's full path in the first line. A server folder holds only Ray, so it goes as a whole. The CLI went in next to whatever was already in its folder, so only its own files go, and the folder leaves your Path only once nothing else is left in it:

```powershell
$d = 'C:\your\folder'
if (Test-Path "$d\ray-server.exe") { Remove-Item $d -Recurse -Force }
Remove-Item "$d\ray-cli.exe", "$d\qt.conf", "$d\Qt6Core.dll", "$d\Qt6Network.dll", "$d\qt6" -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Get-ChildItem $d -Force -ErrorAction SilentlyContinue)) {
  Remove-Item $d -ErrorAction SilentlyContinue
  $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
  $old = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
  $new = ($old -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $d.TrimEnd('\') }) -join ';'
  if ($new -ne $old) { $key.SetValue('Path', $new, 'ExpandString') }
  $key.Close()
}
```

**Homebrew:** `brew uninstall ray-headless`, then `brew untap techspecs/ray-headless`.

**Scoop:** `scoop uninstall ray-headless`, then `scoop bucket rm ray`.

**Chocolatey:** `choco uninstall ray-headless`.

**The `.deb`:** `sudo apt remove ray-headless`.

**The `.pkg`** (macOS):
```sh
[ "$(readlink /usr/local/bin/ray 2>/dev/null)" = /usr/local/ray-headless/ray ] && sudo rm -f /usr/local/bin/ray
sudo rm -rf /usr/local/ray-headless
sudo pkgutil --forget io.techspecs.ray-headless
```

**A `.tar.gz`, `.zip` or the AppImage:** delete the folder you unpacked, or the AppImage file.

**4. Ray's data and settings (optional).** What Ray downloaded, your results, its working data and its settings (see [Where files go](#where-files-go)) stay after steps 1 to 3, and so do its log and cache. For the same user, the Ray app on this computer uses them too: **keep them if you use the app**. `out` holds the subtitles Ray saved there, so copy the ones you want first (subtitles saved next to your videos stay where they are).

Linux:
```sh
rm -rf ~/.local/share/ray/models ~/.local/share/ray/out ~/.local/share/ray/data
rm -rf ~/.local/share/Ray/Ray ~/.cache/Ray/Ray
rm -f ~/.config/Ray/Ray.conf
```

macOS:
```sh
rm -rf ~/.local/share/ray/models ~/.local/share/ray/out ~/.local/share/ray/data
rm -rf ~/Library/"Application Support"/Ray/Ray ~/Library/Caches/Ray/Ray
defaults delete io.techspecs.Ray 2>/dev/null
```

Windows (PowerShell):
```powershell
Remove-Item "$env:LOCALAPPDATA\Ray\models", "$env:LOCALAPPDATA\Ray\out", "$env:LOCALAPPDATA\Ray\data", "$env:LOCALAPPDATA\Ray\Ray" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Ray\Ray' -Recurse -ErrorAction SilentlyContinue
```

The second line on Linux and macOS, and `Ray\Ray` on Windows, are its log and cache. Delete only these folders, never all of `%LOCALAPPDATA%\Ray`: the Ray app keeps its `ray` command in `%LOCALAPPDATA%\Ray\bin`. Moved them with `RAY_MODEL_ROOT`, `RAY_DEVAPI_RESULTS_DIR` or `RAY_LOCAL_STORAGE_ROOT` (or `XDG_DATA_HOME`)? Delete those folders instead.

---

## Using it

- **Create** - upload videos, or pick files on the server (type a path or **Browse**); choose languages, the audio track, Ray Local or Ray Cloud, and whether to save next to the video.
- **Jobs** - live progress, downloads, **Remove** and **Clear finished** (optionally deleting the result files).
- **Watch folders** - subtitle whole folders automatically. [How](docs/docker.md#watch-folders)
- **Connections** - Sonarr and Radarr. [How](docs/docker.md#sonarr-and-radarr)
- **Your devices** - let Ray on your PC do the work. [How](docs/docker.md#use-your-devices-nearby-processing)
- **People** - give each person their own access. [How](docs/docker.md#private-dashboard-people-and-keys)
- The **?** menu replays the guided tours.
- **Command line:** one-shot `generate`, `ray-cli`, and the full `/v1` Developer API: see the [container guide](docs/docker.md).
- **MCP apps** - Cursor and other apps that speak the Model Context Protocol use the server's tools with your key: make and translate subtitles, follow jobs, read subtitles to answer questions. [How](docs/mcp.md)

---

<a id="install-the-cli"></a>

## Install only the CLI

`ray-cli` on its own: a small client for a Ray server that runs somewhere else (in Docker, on a NAS or on another computer), from a terminal, a script or an MCP app. It has **no server and no dashboard**: for those, see [Run the server without Docker](#run-the-server-without-docker).

**One-line install** - downloads `ray-cli` for your system, verifies its checksum, and adds it to your PATH:

Linux / macOS:
```sh
curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh
```

Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex
```

Open a new terminal afterwards so `ray-cli` is on your PATH. Or download it from the [Releases](../../releases) page: `ray-cli-linux-x64-<version>.tar.gz`, `ray-cli-macos-arm64-<version>.tar.gz` or `ray-cli-windows-x64-<version>.zip`.

Then store your key once, checked against your server, and use it:

```sh
ray-cli login ray_... --url http://SERVER-IP:8787
ray-cli api jobs --url http://SERVER-IP:8787
```

`RAY_API_URL=http://SERVER-IP:8787` saves typing `--url`, and `ray-cli --help` lists every command. (The full server installs above include it: there, type `ray` where this says `ray-cli`.)

To remove it again, see [Uninstall](#uninstall): steps 2 and 3 cover the CLI on its own.

---

## Notes

- **Upgrading from 4.0.15-beta.1 or earlier?** `docker compose pull && docker compose up -d`, and read [what changed](docs/docker.md#upgrading-from-an-earlier-image) (file ownership, result names, watch folders saving next to videos).
- **Your seat:** one server = one seat. The server's Ray account connection lives in `ray-config`: keep that volume (and keep it private). `ray-models` holds the downloads; deleting it means downloading again. Without Docker, both stay with the user that runs `ray serve` (see [Where files go](#where-files-go)).
- **Private by default:** reachable from your network, the dashboard shows nothing until someone signs in, and every API request needs a key or a browser's sign-in.
- **API:** `http://SERVER-IP:8787/v1/...` with the key as a Bearer token. See the [container guide](docs/docker.md#api-and-ray-cli). Apps that speak MCP connect at `/v1/mcp` with the same keys: see the [MCP guide](docs/mcp.md).
- **TLS:** the server speaks plain HTTP on 8787 - put it behind a reverse proxy (Caddy / nginx / Traefik) for HTTPS.
- **Telemetry:** crash reporting is on by default; set `RAY_TELEMETRY=off` to turn it off.
- **License:** Ray is proprietary software. © 2026 TechSpecs. All rights reserved. This repository holds distribution manifests and documentation, not source code.
