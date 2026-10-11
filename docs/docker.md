# Ray headless - container guide

Ray's subtitle server in a container: a web dashboard plus the Ray Developer API, without the desktop app. Make, translate, re-time and burn in subtitles on your own hardware (**Ray Local**) or on Ray's servers (**Ray Cloud**), for single videos, whole folders, or every new episode Sonarr and Radarr bring in.

> **New to Docker, or installing on a NAS?** Follow the step-by-step [NAS install guide](nas-install.md) first. This page is the full reference.
>
> **No Docker?** The same server also installs straight on Linux, macOS or Windows: [Run the server without Docker](../README.md#run-the-server-without-docker).

**On this page:** [Which image](#which-image-should-i-use) · [Quick start](#quick-start) · [Signing in](#signing-in) · [The dashboard](#the-dashboard) · [Browse folders](#browse-the-servers-folders) · [People and keys](#private-dashboard-people-and-keys) · [Where results are saved](#where-results-are-saved-and-library-mode) · [Watch folders](#watch-folders) · [Sonarr and Radarr](#sonarr-and-radarr) · [Audio tracks](#videos-with-several-audio-or-subtitle-tracks) · [Ray Cloud](#ray-cloud) · [Your devices](#use-your-devices-nearby-processing) · [Networking](#bridge-or-host-networking) · [Small servers](#ray-local-on-small-servers) · [One-shot mode](#one-shot-mode) · [Removing jobs](#removing-finished-jobs) · [Volumes](#volumes) · [PUID / PGID](#running-as-your-nas-user-puid-pgid-umask) · [GPU](#gpu-passthrough) · [Reverse proxies](#tls-and-reverse-proxies) · [Environment variables](#environment-variables) · [API](#api-and-ray-cli) · [Upgrading](#upgrading-from-an-earlier-image) · [Tags](#tags)

---

## Which image should I use?

| Your hardware | Image | Run with |
|---|---|---|
| **NVIDIA graphics card** (RTX 20-series / GTX 16-series and newer) | `techspecs/ray:cuda` | `--gpus all` - on a Linux host with the NVIDIA Container Toolkit, **and** on Windows with Docker Desktop (WSL2) |
| **A separate AMD graphics card**, Linux host | `techspecs/ray:vulkan` | `--device /dev/dri --device /dev/kfd` |
| **Integrated graphics** (graphics built into the processor: most NAS boxes and mini PCs, a Ryzen with Radeon Graphics, an Intel N100), **Intel graphics** (built in or Arc), **no graphics card**, or **not sure** | `techspecs/ray:cpu` | nothing special |

- The `cuda` image **needs `--gpus all` to start**. On a machine without an NVIDIA card, use `cpu`.
- AMD graphics in Docker need a **Linux** host. On Windows or macOS Docker Desktop, use `cpu` (or the Ray desktop app, which uses the graphics card directly).
- Ray Local doesn't use integrated or Intel graphics, so `cpu` is the right image there. With the `vulkan` image and `/dev/dri` passed in on Intel graphics, jobs may be refused instead of running on the processor.
- Everything works on the processor too: a graphics card makes Ray Local faster, it is not required. No graphics card, but a PC with one on your network? The server can [use your devices](#use-your-devices-nearby-processing).

---

## Quick start

```sh
docker run -d --name ray-server --restart unless-stopped \
  -p 8787:8787 \
  -e PUID=1000 -e PGID=1000 \
  -v ray-config:/config -v ray-models:/models -v ray-data:/data \
  -v "$PWD/out:/out" -v "$PWD/media:/media" \
  techspecs/ray:cpu

docker logs ray-server      # the first start prints a key that starts with ray_ - copy it
```

Then open **`http://SERVER-IP:8787/`** in a browser (`localhost` on your own computer, otherwise the machine's address, like `192.168.1.50`) and [sign in](#signing-in).

- `PUID` / `PGID` are the user and group Ray runs as. On a NAS, use your own (see [Running as your NAS user](#running-as-your-nas-user-puid-pgid-umask)).
- `media` is mounted **read-write**, so Ray can save subtitles next to your videos when you ask it to. Add `:ro` (`"$PWD/media:/media:ro"`) to keep every result in `out` instead.
- For `cuda` add `--gpus all`; for `vulkan` add `--device /dev/dri --device /dev/kfd`.
- Windows PowerShell: end each line of `docker run` with a backtick instead of `\` (or put it all on one line). The `$PWD` paths work as written.
- Prefer Docker Compose? Use the ready [`compose.yaml`](../compose.yaml) in this repo.
- The first job downloads what Ray needs (a few GB) into `ray-models`. Keep that volume and later jobs start right away.

Port 8787 already taken? Change only the **first** number: `-p 8080:8787`, then open `http://SERVER-IP:8080/`.

---

## Signing in

There are two separate things:

1. **You sign in to the dashboard.** In Docker the server is private: the page shows only its sign-in screen until you prove who you are.
2. **The server is connected to a Ray account.** That is what lets it download what it needs, use Ray Cloud and count as your seat. Everyone who signs in to the dashboard uses the server's connection.

### First time: the key, then your Ray account

Four steps: copy the key from the log, sign in with it, connect the server to your Ray account, and check that it worked. This is the default setup. With `RAY_APP_SIGNIN` set to `on`, step 2 is different: see [Set up a new server with the app](#set-up-a-new-server-with-the-app).

**1. Copy the key from the log.** At its first start the server prints an **owner key** in its log, in a box between two lines of `=====`:

```
==============================================================================
 Ray generated an API key for this server (no key was configured):

     ray_...

 This is the OWNER key. Open the dashboard (http://this-host:PORT/), paste
 ...
==============================================================================
```

The key is the line that starts with `ray_`: copy all of it, `ray_` and 48 letters and digits. To show just that part of the log:

- **Linux, or a NAS over SSH** ([open a terminal on your NAS](nas-install.md#step-1---open-a-terminal-on-your-nas)):

  ```sh
  sudo docker logs ray-server 2>&1 | grep -A3 "generated an API key"
  ```

- **Windows with Docker Desktop**, in PowerShell:

  ```powershell
  docker logs ray-server 2>$null | Select-String "generated an API key" -Context 0,3
  ```

  Or in Docker Desktop: **Containers** > `ray-server` > **Logs**.

- **Docker Compose**, in the folder with your `compose.yaml` (`sudo` in front on a NAS):

  ```sh
  docker compose logs ray-server
  ```

  Each line starts with `ray-server` and a `|`: copy only the key, from `ray_` to the end of its line.

It is shown only this once: the key is stored hashed in `/config`, so Ray can't show it again. Copy it before you remove or recreate the container, because a new container that keeps the same `ray-config` volume doesn't print it again. Nothing found? See [Lost the key](#lost-the-key).

**2. Sign in with the key.**

1. Open `http://SERVER-IP:8787/`. The page says **Set up this Ray server**: "Paste the key from the server log to sign in."
2. Paste the key into the field that says **Paste your API key**. (**Show** shows what you pasted.)
3. Under the button, **Keep me signed in on this browser** is ticked, so this browser keeps the key until you sign out. Untick it first on a computer you share.
4. Choose **Sign in**. A message at the top right says **Signed in. Now connect this server to your Ray account.**
5. A short tour, **Get to know your Ray server**, may open: choose **Show me around**, or **Skip tour** (the **?** button replays it).

"That key didn't work. Check it and try again." means part of the key is missing, or something else came along: copy the whole line that starts with `ray_` again. Opened from outside your home network, or under a name the server doesn't know, the page says **Sign in with an API key** instead: the same key and **Sign in** work there.

**3. Connect the server to your Ray account** with an emailed code:

1. On **Create**, find the card **This server's Ray account** and choose **Use an email code instead**.
2. A window, **Connect a Ray account**, opens. Type your Ray account's email under **Email** and choose **Send code**.
3. The window says "We emailed a code to" your email. Type the 6-digit code from that email under **Code from the email** and choose **Verify**. (Nothing came? Check the spam folder, or choose **Send a new code**. A typo in the address? Choose **Use a different email**.)
4. If your email can use more than one Ray account, the window says **Choose a Ray account**. Choose the one this server should use: **My own Ray account** is yours, a row with a name, like **Sam's Ray account**, is an account you belong to. A row that says "Waiting for ... to confirm you" can't be chosen yet.

Or with the Ray app on your Windows PC or Mac, open and signed in to your Ray account: in step 1 choose **Connect with your Ray app** instead. The window says **Choose a device**: pick your computer. On that computer, check that the code matches the one on the page and choose **Approve sign-in**. Back on the page, **Connect this server to this Ray account?** shows the account: choose **Connect**. On Docker's default bridge network the list stays empty and a typed address is refused until `RAY_NEARBY_LAN_SUBNETS` is set (see [The computer isn't listed?](#the-computer-isnt-listed)): use the email code then.

**4. Check that it worked.** A message at the top right says **Connected this server to** your email, and the card **This server's Ray account** shows **Connected to** with your email, partly hidden. You are signed in as the owner, and the server is connected to your Ray account.

### Sign in with your Ray app

It is **off** until an owner turns it on: at the top of **People**, the **Sign in with your Ray app** tile has **Turn on** (it asks first). Or set `RAY_APP_SIGNIN: "on"` where the container starts; the tile then says **Set at startup**. From then on the page says **Sign in to this Ray server**: choose **Sign in**, pick your computer under **Choose a device**, check that the code on your computer matches the one on the page, and choose **Approve sign-in** there. (A browser that used a key last time opens on the key, with **Sign in with your Ray app instead** under it.)

- Only the owner of the Ray account the server is connected to can sign in this way, with Ray 4.0.16 or later on a computer (Windows or Mac) that is open, signed in to that account and on the same network as the server. Members of that Ray account, other accounts and older Ray are refused; they use a [sign-in link](#sign-in-links) or a key.
- It works only from the server's own network. Away from home (and through Tailscale, whose addresses count as outside) use a key or a sign-in link.
- **Keep me signed in on this browser** keeps you signed in for 30 days after you last used it (at most 90 days); without it, for 12 hours.
- **Use an API key instead** under the button always works, also for scripts and recovery.

#### Set up a new server with the app

With `RAY_APP_SIGNIN: "on"` from the first start, step 2 of [First time](#first-time-the-key-then-your-ray-account) goes like this (step 1, the key from the log, is the same):

1. Open `http://SERVER-IP:8787/`. The page says **Set up this Ray server**: "Paste the key from the server log to show this server is yours."
2. Paste the key into **Key from the server log**. On a computer you share, untick **Keep me signed in on this browser** (under the button). Then choose **Continue**.
3. The page says **Choose a device**. Pick your computer: Ray open on it, signed in to your Ray account.
4. The page says **Approve on** and your computer's name, with a code. On that computer, check that the code matches and choose **Approve sign-in**.
5. The page asks **Connect this server to this Ray account?** Check the account it shows and choose **Connect and sign in** (or **This isn't my account**). A message says **Connected this server to** your account **and signed you in**: steps 3 and 4 of First time are done too.

**No computer in the list?** On Docker's default bridge network without `RAY_NEARBY_LAN_SUBNETS`, the page says "This server can't look for devices on your network by itself." At the bottom, after **No Ray app?**, choose **Continue with the key only**. A message says **Signed in with the key. This server isn't connected to a Ray account yet.** Then connect it with the email code: [step 3 of First time](#first-time-the-key-then-your-ray-account). (Or set `RAY_NEARBY_LAN_SUBNETS`, see below, and try again.) After **Continue** the page keeps the key for 15 minutes; after that it says "Paste the key again to continue."

To skip the key, add your Ray account's email as well and restart the container: until the server is connected, only that Ray account can set it up. The page then says **Set up this Ray server** with **Continue** and no key field. Anyone who holds that account's license key can approve such a setup, so the key from the log is the safer way.

```yaml
    environment:
      RAY_APP_SIGNIN: "on"
      RAY_OWNER_EMAIL: "you@example.com"
```

`RAY_OWNER_EMAIL` does nothing while app sign-in is off (the log says so), and only matters until the server is connected; after that the log warns if it names a different account.

#### The computer isn't listed?

On Docker's default bridge network the server can't look for computers by itself. Set `RAY_NEARBY_LAN_SUBNETS` to your home network (the server's address with its last number replaced by `0/24`: `192.168.1.50` -> `192.168.1.0/24`) and start the container again: then the list shows the computers added in Your devices. For a computer that isn't listed, choose **Enter an address** (under a list of computers it is the link **Enter an address instead**), type the computer's address (for example `192.168.1.20`) under **Computer's address**, and choose **Send request**. Without the setting the list is empty and a typed address is refused with "That address isn't on this server's network." With host networking or macvlan the list fills by itself (see [Bridge or host networking](#bridge-or-host-networking)).

### Sign-in links

The easiest way to let someone else in: **People > Add person**, type their name, choose **With a sign-in link** and **Add person**. Send them the link. It works **once**, within **24 hours**, and signs in one browser, with no key to copy. Whoever opens it first becomes that person on this server, so send it only to them. A person who needs another browser gets a new link from **Send a new sign-in link** on their row.

### This server's Ray account

On the **Create** tab, **This server's Ray account** shows which Ray account the server is connected to. Owners can:

- **Switch account** - approve on a computer signed in to the other Ray account, or use an emailed code. Browsers that signed in with the Ray app then sign in again.
- **Disconnect** - it asks first. The server can't download what it needs or use Ray Cloud until you connect it again, and browsers that signed in with the Ray app are signed out. Keys and sign-in links keep working.
- Not connected yet: **Connect with your Ray app** (this works while app sign-in is off too), or **Use an email code instead** (Ray emails you a one-time code). Step by step: [step 3 of First time](#first-time-the-key-then-your-ray-account).

### Turning app sign-in off

In **People**, the **Sign in with your Ray app** tile says **On** or **Off**, with **Turn off** or **Turn on** (turning it off signs out the browsers that signed in this way; keys and sign-in links keep working). `RAY_APP_SIGNIN=local` allows it only from the server's own network with no reverse proxy in between (in a bridge container, only from the networks in `RAY_NEARBY_LAN_SUBNETS`); `RAY_APP_SIGNIN=off` turns it off. Setting `RAY_APP_SIGNIN` at all (`on`, `local` or `off`) locks the switch.

### Sign in with an API key

The first start prints the **owner key** once in the container log (how to find it: [step 1 of First time](#first-time-the-key-then-your-ray-account)):

```sh
docker logs ray-server
```

Copy the line that starts with `ray_`, paste it into **Paste your API key** on the sign-in screen and choose **Sign in**. It is stored hashed in `/config`, so later starts don't print it again. Don't share it: give everyone else their own way in from **People** (see below).

### Lost the key

The log shows the key only at the first start, and Ray keeps only a fingerprint of it, so it can't show it again. To get a new owner key:

- **Still signed in on a browser?** Open **People**. On the row called **Owner** (the key from the log), choose the **⋯** button, then **Replace their API key** and **Replace key**. Copy the new key with **Copy key**: it's shown only this once. The old key stops working at once (if this browser signed in with it, this browser switches to the new one).
- **Signed out everywhere?** Make a key of your own and give the server its hash in `RAY_DEVAPI_KEY_HASH`. Everything in `/config` stays: the server's Ray account, People, the other keys.

  Linux, a NAS over SSH, or a Mac (on a Mac, `shasum -a 256` for `sha256sum`):

  ```sh
  KEY="ray_$(openssl rand -hex 24)"
  echo "Your new key: $KEY"
  printf %s "$KEY" | sha256sum | cut -d' ' -f1      # this is the hash
  ```

  Windows (PowerShell):

  ```powershell
  $bytes = [byte[]]::new(24); [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $key = "ray_" + -join ($bytes | ForEach-Object { $_.ToString("x2") })
  "Your new key: $key"
  -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($key)) | ForEach-Object { $_.ToString("x2") })   # this is the hash
  ```

  Keep the new key. Then give the container the hash and start it again:

  - **Docker Compose:** add `RAY_DEVAPI_KEY_HASH: "paste-the-hash-here"` under `environment:` in `compose.yaml`, then `docker compose up -d`.
  - **docker run:** remove the container (`docker rm -f ray-server`: the volumes keep everything) and start it again with your `docker run` line plus `-e RAY_DEVAPI_KEY_HASH=paste-the-hash-here`.

  The log then says `imported 1 API key hash(es) from RAY_DEVAPI_KEY_HASH`. Sign in with the new key, and leave the line in place. Paste the **hash** there, never the key: an entry that starts with `ray_` is skipped, and the log says so.
- **Don't delete the `ray-config` volume** to get a new key. The next start would print one, but the volume also holds the server's Ray account connection (your seat), People, watch folders and connections.

### Connect the server to your Ray account without the dashboard

- **From a terminal** (emailed one-time code, stored in `/config`):

  ```sh
  docker run -it --rm -e PUID=1000 -e PGID=1000 -v ray-config:/config techspecs/ray:cpu login
  ```

  Use the same `PUID` / `PGID` as your server (see [Running as your NAS user](#running-as-your-nas-user-puid-pgid-umask)).

- **From the environment:** set `RAY_ACCOUNT_EMAIL` and `RAY_ACCOUNT_LICENSE_KEY` (your Ray license key, shown with a copy button on the account screen of the Ray desktop app).

Signing in needs a writable `/config`. When it isn't, Ray refuses the sign-in and says why, instead of forgetting it at the next start. Your key keeps working until the server stops: see [Settings can't be saved](nas-install.md#settings-cant-be-saved) for what else works until you fix it.

---

## The dashboard

`http://SERVER-IP:8787/` is a single page served by the server itself: no CDN, no outside fonts, it works without internet access. Tabs:

| Tab | Who | What it does |
|---|---|---|
| **Create** | everyone | Upload videos (drag and drop, many at once, each becomes its own job) or **Use a server path** (a file or folder inside a mounted volume, like `/media/movies/Movie.mkv`). Pick what to do (**Create subtitles**, **ReTime a subtitle**, **Translate a subtitle**, **Submerge** to burn them into the video, or several steps together), languages, **Run on** (Ray Local or Ray Cloud), subtitle quality (Moonlight or Sunlight), the audio track, where the result is saved, and the subtitle source. |
| **Jobs** | everyone | Live progress, where each job runs, where its subtitle came from and where it was saved, errors with what to do. Download, cancel, retry, **Remove** and **Clear finished**. Members see their own jobs. |
| **Logs** | owners | What the server did, with a search and a level filter. |
| **Watch folders** | owners | Folders Ray subtitles by itself. |
| **Connections** | owners | Sonarr and Radarr. |
| **Your devices** | owners | Ray on your computers makes subtitles for this server, or sends its work here. |
| **People** | owners | Who can use the server. |
| **Help** | owners | A connection test (how well the server reaches Ray) and **Copy diagnostics** to send to Ray support. |

The **?** (Help) menu replays the guided tours (**Take a tour**) and turns **Show guides the first time I open a tab** on or off.

---

## Browse the server's folders

No more copying paths from a terminal. Every field that takes a path on the server (**Path on the server** on Create, the subtitle to ReTime or translate, a watch folder's **Folder on the server**, and a Sonarr or Radarr connection's folder) suggests matching folders and files as you type: **Tab** completes the name and goes into that folder, the arrow keys move, **Enter** takes the highlighted one and **Esc** closes the list.

**Browse**, next to the field, opens at the path already in the field, or on **Places** when it is empty: the **Favorites**, your **Recent** folders and what is **On this server**. For the subtitle to ReTime or translate, an empty field opens in the folder of the video you picked. Each folder shows the size of each file, the subtitle languages already next to each video, and a line such as "40 folders and 12 videos, 8 with English subtitles". **Use this folder** (or **Use this file**, **Use this video**, **Use this subtitle**) fills in the field. Opened from Create, **Watch this folder** (owners) opens **Add a watch folder** with that folder filled in.

- **What shows:** in Docker, the volumes you mounted and the output folder. Never `/config`, `/models`, Ray's own folders in `/data`, `/tmp` or the system's folders. Read-only mounts say **Read-only**, and a share that is asleep or disconnected says **Not responding**. Installed without Docker: the home folder, the drives and the mounted volumes, without Ray's own or the system's folders.
- **Favorite folders:** owners save a folder with the heart in **Browse**, and rename or remove it with **Edit**, where **Who can use it** chooses which members set to **Favorites only** may use it. Favorites come first, with their free space. A server keeps up to 50.
- **Recent folders** are yours alone: the last 10 folders you used for jobs, watch folders and connections. **Clear** empties the list.
- **Paths as your NAS names them:** owners can type or paste `/volume1/video/Movies` or `\\DS920\video\Movies`, and Ray offers the path inside the container (`/media/Movies`) when that folder is mounted.
- **Who can browse:** owners, and members within their **Can browse** setting in [People](#private-dashboard-people-and-keys). Members never see the output folder unless `RAY_MEMBER_JOBS=all`. MCP apps browse only with an owner's key. A server that runs without any key never lists its folders, and `RAY_BROWSE` limits or turns browsing off (see [Environment variables](#environment-variables)).

Browsing shows names, kinds and sizes only: it never opens a file and never writes anything. A folder that can't be listed says why instead of showing an empty list.

From a terminal: `ray-cli api browse /media/movies` (one folder), `ray-cli api browse` (the places to start from), `ray-cli api favorites` (favorites and recent folders) and, for owners, `ray-cli api favorites add /media/movies --name Movies`, `rename ID NAME` and `remove ID`. Over HTTP: `GET /v1/browse`, `GET` and `POST /v1/browse/favorites`, `PUT` and `DELETE /v1/browse/favorites/{id}`, and `DELETE /v1/browse/recent`.

---

## Private dashboard, People and keys

Whenever the server can be reached from the network (always, in Docker) it is **private**: the page shows only its sign-in screen, nothing about the server or its jobs loads before sign-in, and every request except the page itself, its sign-in steps and a bare `/v1/health` needs a key or a browser's sign-in (Sonarr and Radarr use their connection's own password instead). No address is trusted, not even the server's own machine. When a key or a sign-in stops working, a page using it locks again.

**People** (owners) lists everyone who can use the server. **Add person**, type a name, and turn on **Can manage this server** only for other owners. For a member, choose what they **Can browse** (it starts at **Favorites only** with **All favorites**).

- **With a sign-in link** (recommended): see [Sign-in links](#sign-in-links).
- **With a key**: for scripts and the command line. The key is shown **once**, with a Copy button.
- **Send a new sign-in link** on a row makes another link for that person (each link signs in one browser).
- The row's **More** menu has **Signed-in browsers** (sign one out, or **Sign out everywhere**), **Create an API key** or **Replace their API key** (the old key stops working; browsers that signed in with a link stay signed in), **Cancel unused link**, and **Remove person**, which stops that person at once: their key and links stop working and every browser they're signed in on is signed out. **Make owner** (it asks first) and **Make member** change someone's role; a member's **Can browse** comes back when they're a member again.
- **Can browse** (members): **Favorites only**, with **All favorites** (also the ones added later) or **Only these** (the favorites you tick), or **Everywhere** (every folder owners can browse). It decides which of the server's folders they can browse and use for jobs, retries included; uploading always works. Change it on their row, or choose who can use one favorite with **Edit** on it in **Browse**. Narrowing someone never stops jobs they already added. A member set to **Favorites only** with no favorite they may use can only upload files until you share one. See [Browse the server's folders](#browse-the-servers-folders).

| | Owner | Member |
|---|---|---|
| Add jobs, see and manage them | every job | only their own (`RAY_MEMBER_JOBS=all`: see, cancel, retry and remove every job; delete result files only of their own) |
| Use Ray Cloud | yes (through the server's Ray account) | yes (through the server's Ray account) |
| Pick files that are on the server | yes | yes, except Ray's own and system folders, paths with a `.` or `..` folder in them and, unless `RAY_MEMBER_JOBS=all`, other people's results in the output folder. Set to **Favorites only**: only inside the favorite folders they may use. Uploading always works. |
| Browse the server's folders, use favorites | yes | the favorite folders they may use, or every folder when set to **Everywhere** (the output folder only with `RAY_MEMBER_JOBS=all`) |
| Save favorite folders | yes | no |
| Logs, graphics choice, the server's Ray account | yes | no |
| Watch folders, Connections, Your devices, People | yes | no |

The Jobs list shows who added each job (**Added by**); watch folder and Sonarr / Radarr jobs say where they came from.

From a terminal (with an owner key in `RAY_API_KEY`): `ray-cli api keys`, `ray-cli api keys create NAME --role member`, `ray-cli api keys revoke KEY_ID`, `ray-cli api invites create NAME --role member` (prints a sign-in link once), `ray-cli api sessions` (the signed-in browsers), `ray-cli api whoami`, `ray-cli api keys folders KEY_ID favorites|everywhere [--favorites all|none|ID,...]` (what a member can browse; `keys create` and `invites create` take `--folders` and `--favorites` too) and `ray-cli api keys role KEY_ID owner|member`.

Keys set with `RAY_DEVAPI_KEY_HASH` are owner keys managed where the server starts: remove a hash and restart to revoke it. The last owner key can't be revoked. The variable takes each key's sha256, never the key itself: an entry that starts with `ray_` is skipped, and the log says so and shows how to make the hash (or see [It asks for a key and I don't have one](nas-install.md#it-asks-for-a-key-and-i-dont-have-one)). While it is set, the first start makes no key of its own.

---

## Where results are saved (and library mode)

Every result is **named after its video** plus the language: `Movie.en.srt`. Regional variants keep their region (`Movie.pt-BR.srt`, `Movie.zh-Hant.srt`); `RAY_OUTPUT_LANGUAGE_CODES=short` uses two letters only. Names use the two-letter language code whenever the language has one, the kind media servers read (`Movie.nl.srt`, `Movie.zh.srt`). When a name is taken the new file gets a number (`Movie (2).en.srt`): **nothing is ever overwritten**. When two videos in one folder share a name (`Movie.mkv` and `Movie.mp4`), the subtitles keep the video's extension (`Movie.mkv.en.srt`) so each video gets its own.

A result goes to one of two places:

| Place | Where | Default for |
|---|---|---|
| **Output folder** (`out`) | `/out` in the container | jobs from the dashboard, the API and one-shot `generate` |
| **Next to the video** (`beside`, library mode) | the video's own folder, where Plex, Jellyfin and Emby find it | watch folders and Sonarr / Radarr connections |

Choose per job with **Save next to the video (for Plex, Jellyfin and Emby)** on the **Use a server path** tab (or `"output": "beside"` over the API), and per watch folder or connection with **Save subtitles**. `RAY_OUTPUT=beside` or `RAY_OUTPUT=out` changes the default for dashboard, API and watch folder jobs; Sonarr and Radarr connections always follow their own **Save subtitles** (next to the video unless you change it).

**Library mode needs the media mounted read-write**, and writable by the user Ray runs as (`PUID`). Ray then:

- saves only `.srt` and `.vtt` subtitles next to the video (burned-in copies always go to `/out`);
- never replaces a subtitle it didn't make. If the name is taken, or the folder is read-only (`:ro`), or Ray may not write there, the result goes to `/out` and the job says why (also in `docker logs`);
- uses `/out` for uploads (there is no video folder to save next to), for a ReTime of a subtitle you already have, and when the language can't be told;
- keeps one copy: the subtitle next to the video *is* the result, and the dashboard download still works.

After a batch, let your media server rescan the library to pick up the new subtitles.

---

## Watch folders

Ray subtitles every video in a folder, and each new one that arrives (network shares included: a regular rescan backs up the file events). Nothing is processed twice, also across restarts.

### From the dashboard (no restart)

1. Open **Watch folders** and choose **Add folder**.
2. **Folder on the server**: the path **inside the container**, like `/media/movies` (not the path on your NAS).
3. **Subtitle language(s)**: each language gets its own subtitle file. "Same as the audio" keeps the spoken language.
4. **Steps**: Create subtitles is always on; tick **Also burn the subtitles into a copy of the video** for a burned-in copy (saved in `/out`, the original is never changed).
5. **Process with**: **Ray Local** (this server) or **Ray Cloud** (see [Ray Cloud](#ray-cloud)). With Ray Local, **Use Ray Cloud if Ray Local can't** hands a video to Ray Cloud when this server can't make its subtitles.
6. **Where it runs** (only when the server uses [your devices](#use-your-devices-nearby-processing)).
7. **Audio language** and **More than one audio track** for videos with several audio tracks, **Translate from subtitles in** and **More than one subtitle inside a video** for videos that already carry subtitles inside them (all optional; when the language doesn't decide, a new folder uses the video's default, or choose **Ask me in the Jobs list**).
8. **Save subtitles**: **Next to each video - for Plex, Jellyfin and Emby** (needs a read-write mount) or **In the output folder**.
9. **Also subtitle the videos already in this folder**, or only new arrivals.
10. **Add folder**.

Ray checks the folder first: it must exist inside the container, be readable, and be writable for library mode. In Docker it must be inside a volume you shared with the container (like `/media/movies` in a `/media` volume), or be a folder that holds such volumes (like `/media` with `/media/movies` and `/media/tv` mounted). Ray's own folders, the output folder, and a folder that is already watched or overlaps one are refused. A folder saved before these checks keeps watching, and the tab says what to change. Each folder can be paused, changed, rescanned and removed. A folder that goes missing (a share that isn't mounted yet) shows as missing and is picked up again when it comes back. Removing a folder keeps its history, so adding it back never redoes finished videos.

**Which videos are skipped:** with library mode, a video is skipped only for the languages that already have a subtitle next to it. `Movie.nl.srt` (or `Movie.nl.sdh.srt`) skips Dutch; a forced-only `Movie.nl.forced.srt` doesn't; a subtitle without a language in its name (`Movie.srt`) counts for every language. A folder that saves to `/out` skips a video that has any subtitle next to it.

### From the command line or the environment

```sh
docker run -d --name ray-watch -e PUID=1000 -e PGID=1000 \
  -v ray-config:/config -v ray-models:/models -v ray-data:/data \
  -v "$PWD/out:/out" -v /srv/media:/media \
  techspecs/ray:cpu watch /media --lang nl
```

- `--lang` is **required** (Ray never guesses a target language). Several: `--lang nl,en`.
- Each folder its own settings: `watch /media/films --lang nl /media/lectures --lang de --watch-tasks create,translate --watch-output out`. Steps come from `create`, `sync` (ReTime), `translate`, `submerge` (burn in), in that order.
- As environment variables with the normal server: `RAY_WATCH_DIRS=/media` and `RAY_WATCH_LANGS=nl`, or per folder with `RAY_WATCH_CONFIG`:

  ```yaml
      environment:
        RAY_WATCH_CONFIG: >-
          [{"dir":"/media/films","languages":["nl"]},
           {"dir":"/media/anime","languages":["en"],"audio_language":["ja"],"fallback_to_cloud":true},
           {"dir":"/media/lectures","languages":["de"],"tasks":["create","translate"],"output":"out"}]
  ```

  Optional keys: `tasks`, `output` (`beside` or `out`), `target` (`local` or `cloud`), `fallback_to_cloud`, `run_on` (`server`, `auto` or `devices`), `audio_language`, `subtitle_source_language`, `process_existing`, `enabled`.

Folders set at startup show in the dashboard as **Set at startup** and can only be changed where the container starts. `RAY_WATCH_EDITABLE=0` locks the whole list. Watch jobs appear in the Jobs list next to other jobs.

---

## Sonarr and Radarr

Ray can make subtitles for every new episode and movie the moment Sonarr or Radarr brings it in. They tell Ray through their built-in **Webhook** connection; no extra software.

### Set it up

**In Ray's dashboard:**

1. Open **Connections** and choose **Connect Sonarr** (or **Connect Radarr**). Once you have a connection, more are added with **Add a connection** > **Sonarr** or **Radarr**.
2. **Your shows on this server**: the folder with your shows **as Ray's container sees it**, for example `/media/tv`. **Add another folder** for more.
3. **Subtitle language(s)**. **More options** has the same choices as a watch folder (Ray Local or Ray Cloud, **Audio language**, **Save subtitles**, **Tidy up after Sonarr**).
4. Choose **Connect**. The new card shows a **Webhook URL** and a **Password**. **Copy the password now** - Ray shows it only once (you can make a new one later).

**In Sonarr** (Radarr is the same):

1. **Settings > Connect**, click **+** and choose **Webhook**.
2. **Name**: `Ray`.
3. **Notification Triggers**: leave them as Sonarr sets them for a new Webhook (almost every box ticked). Make sure **On File Import** and **On File Upgrade** are ticked. Ray also uses **On Import Complete**, **On Rename**, **On Series Delete**, **On Episode File Delete** and **On Episode File Delete For Upgrade** (Radarr: **On Rename**, **On Movie Delete**, **On Movie File Delete**, **On Movie File Delete For Upgrade**) to follow renames, better copies and deletes. The other boxes do no harm.
4. **Tags**: leave empty for every show, or see [Several instances and choosing shows](#several-instances-and-choosing-shows).
5. **Webhook URL**: paste Ray's Webhook URL (see [The address Sonarr uses](#the-address-sonarr-uses)).
6. **Method**: `POST`.
7. **Username**: leave empty. **Password**: paste Ray's password.
8. Click **Test**. When Ray's card says **Test received**, click **Save** in Sonarr.

Only **new** episodes and movies are subtitled. For the ones you already have, add the same folder under [Watch folders](#watch-folders): Ray makes each video's subtitles once, whichever hears about it first.

### The address Sonarr uses

The Webhook URL is the address Sonarr uses to reach Ray, plus `/v1/hooks/<id>` (`/v1/hooks/sonarr` for the first Sonarr connection):

- **Sonarr in the same compose file as Ray:** `http://ray-server:8787/v1/hooks/sonarr` (`ray-server` is the name of Ray's service; use yours).
- **Anywhere else:** the NAS's own address and the port Ray is published on, for example `http://192.168.1.50:8787/v1/hooks/sonarr`.

`127.0.0.1` never works from another container: there it means that container itself.

### When Sonarr and Ray see different folders

When Sonarr's container calls the folder `/tv` or `/data/media/tv` and Ray's calls it `/media/tv`, the connection keeps a folder pair: "Sonarr calls it `/data/media/tv` - Ray finds it at `/media/tv`". You only give Ray's side: Ray learns Sonarr's side from the first episode Sonarr sends (when exactly one file of that size turns up in your folders) and shows it as **Learned**. To set it yourself, open **Does Sonarr see this folder under a different path?** and fill in **Sonarr calls it**. An episode Ray can't find shows under **Recent** with where Sonarr said it is and where Ray looked; fix the folder, then choose **Try again**.

Simplest of all: mount the media at the same path in Sonarr, Radarr and Ray.

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    ports:
      - "8787:8787"                     # the dashboard
    volumes:
      - ray-config:/config
      - ray-models:/models
      - ray-data:/data
      - ./out:/out
      - /srv/data/media:/data/media     # the same path Sonarr and Radarr use, read-write
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    volumes:
      - /srv/data:/data
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    volumes:
      - /srv/data:/data

volumes:
  ray-config:
  ray-models:
  ray-data:
```

Then connect Sonarr with the folder `/data/media/tv` and Radarr with `/data/media/movies`, with the Webhook URLs `http://ray-server:8787/v1/hooks/sonarr` and `http://ray-server:8787/v1/hooks/radarr`.

### What Ray makes

- One subtitle per language, next to the video, named with two-letter codes: `Episode.en.srt`, `Episode.pt.srt`. Those are the names Sonarr and Radarr keep when they rename a video. (A connection can use regional codes with `"language_codes": "regional"`.)
- A subtitle that is already there is never replaced, and a language that already has a subtitle next to the video is skipped - the same rules as watch folders.
- With **Save subtitles** set to **In the output folder**, they go to `/out` instead.
- The audio track in the show's or movie's original language is preferred when a video has several; **Audio language** changes that.

### Renames, better copies and deletes

With **Tidy up after Sonarr** on (the default), Ray follows what Sonarr does to a video, but only for subtitles Ray made itself and nobody changed since:

- **Rename:** Ray moves its subtitles to the new name.
- **Better copy (upgrade):** Ray removes the subtitles it made for the old file and makes new ones for the new file (also with tidying off: their timing belongs to the old file).
- **File deleted:** Ray removes its subtitles, only once the video is really gone.
- **Show or movie deleted:** Ray stops following it and deletes nothing.

Subtitles that came with a release, that you edited, or that another tool made are never touched.

### While Ray was off

Sonarr and Radarr don't resend a notification after a failure. So each time Ray starts, it looks through each connection's folders for videos that arrived while it was off, and once more 65 minutes later. What it finds shows under **Recent** as **Found**. When more than 50 videos turn up at once (a moved library, say), Ray makes nothing on its own: the card asks, with **Make them** and **Leave them**. **Look for episodes Ray missed** in a card's **More** menu runs the same look on demand.

### Several instances and choosing shows

Add one connection per Sonarr or Radarr with **Add a connection** (for example **Sonarr 4K**); each gets its own address and password. Sonarr's **Tags** field on the Webhook limits it to some shows: give the Webhook and those shows the same tag. Other languages for some shows (Japanese audio and English subtitles for anime, say)? Add a second connection and split the shows with tags.

### When something goes wrong

| What you see | What it means |
|---|---|
| Sonarr's Test says `[401:Unauthorized]` | The password is wrong. Copy it again from Ray's card, or make a new one there. |
| Sonarr's Test says `[409:Conflict]` | The address belongs to a connection for the other app. Add a Radarr connection for Radarr. |
| Sonarr can't connect, or the Test times out | Sonarr can't reach that address. See [The address Sonarr uses](#the-address-sonarr-uses). |
| Sonarr shows "Notifications unavailable due to failures" | Sonarr paused the connection after Ray didn't answer (Ray was off or unreachable). It tries again by itself, and Ray [catches up](#while-ray-was-off). |
| An episode shows under **Recent** as not found | Ray looked in the wrong folder. Check the folder pair, then **Try again**. |

### Set connections where the server starts

```yaml
    environment:
      RAY_CONNECTIONS: >-
        [{"id": "sonarr", "kind": "sonarr", "name": "Sonarr",
          "password_sha256": "<sha256 of the password>",
          "folders": [{"arr": "/tv", "ray": "/media/tv"}],
          "languages": ["en"], "output": "beside"}]
```

Make a password with `openssl rand -hex 20` and put `rh_` in front of it (for example `rh_5f0c...`); that goes into Sonarr's **Password** field. Its hash for `password_sha256` comes from `printf %s "rh_5f0c..." | sha256sum`. These connections show as **Set where the server starts**. An entry that can't work stops the server with the reason. `RAY_CONNECTIONS_EDITABLE=0` locks the Connections list.

From a terminal: `ray-cli api connections add sonarr --folder /media/tv --language en --address http://ray-server:8787` prints the Webhook URL and password once; `ray-cli api connections` lists them, `ray-cli api connections show ID` shows one with its recent notifications, `ray-cli api connections catch-up ID` looks for missed episodes.

---

## Videos with several audio or subtitle tracks

An anime with Japanese audio and an English dub, a film with a commentary track: Ray makes the subtitles from **one** audio track per job, and never picks one by itself:

1. the track you pick (the dashboard's **Audio track** picker, `audio_track`, `--audio-track`);
2. otherwise the first track in your preferred languages (the dashboard's **Preferred audio language**, a watch folder's or connection's **Audio language**, `audio_language`, `--audio-language`, or for the whole server `RAY_AUDIO_LANGUAGE=ja,en`);
3. otherwise what you chose for videos with more than one track: **Use the video's default**, or **Ask me in the Jobs list** (the job waits there until you choose, and Ray remembers your answer for that video). An API or `ray-cli` job that names no track and neither `default` nor `ask` ends with `track_choice_required` and lists the tracks.

When Ray picks by language it passes over commentary and audio description tracks, unless they are the only ones in that language. Every step of a job uses the same track, and only that track is sent to Ray Cloud or to your devices.

**In the dashboard:** when a single video on the **Use a server path** tab (or a single upload) has more than one audio track, the form shows an **Audio track** picker (rows like "Track 2 - Japanese"), with the one you chose before for that video, or its default, selected. For a folder or several uploads it shows **Videos with more than one track** (**Ask me in the Jobs list**, the default, or **Use the video's default**) and **Preferred audio language**. **Translate** can also start from **A subtitle inside the video**: pick one of its subtitle tracks.

**From a terminal:**

```sh
docker run --rm -e PUID=1000 -e PGID=1000 -v ray-config:/config -v "$PWD/media:/media:ro" techspecs/ray:cpu tracks /media/anime.mkv   # list tracks
ray-cli api submit /media/anime.mkv --language en --audio-track 2
ray-cli api submit /media/anime.mkv --language en --audio-language ja,en
ray-cli api submit /media/movie.mkv --subtitle-track 3 --language de                 # translate subtitle track 3
```

---

## Ray Cloud

Ray Cloud makes subtitles on Ray's servers - handy on a small NAS. It uses the server's Ray account (see [Signing in](#signing-in)); only the audio of the video (the chosen track) leaves the server.

- **One job:** on **Create**, set **Run on** to **Ray Cloud**.
- **A watch folder or connection:** set **Process with** to **Ray Cloud** (for folders that only create subtitles; a folder that also burns in runs on Ray Local).
- **Only when needed:** keep **Ray Local** and tick **Use Ray Cloud if Ray Local can't** (API: `"fallback_to_cloud": true`). A video goes to Ray Cloud only when this server can't make its subtitles.

When Ray Cloud doesn't offer a quality right now, the dashboard greys it out and switches to one that is available.

---

## Use your devices (Nearby processing)

A NAS often has no graphics card, while the PC next to it has one. With **Use your devices**, the server hands the work of making subtitles to Ray on the computers you approve and gets the subtitles back. Jobs, watch folders and results stay on the server: a subtitle made on a computer is named and saved exactly as if the server had made it. It is **off** until an owner turns it on.

### Set it up

1. **On each computer:** open Ray (4.0.15 or later), go to **Settings > Processing** and turn on **Available to Nearby devices**.
   - **Windows:** set the network to **Private** (Settings > Network & internet > your connection > Network profile type > **Private network**). On a Public network Windows blocks the connection.
   - Give the computer a fixed address in your router, so it keeps the same one.
2. **In the dashboard:** open **Your devices** and choose **Turn on** (step 1 of the setup), or set `RAY_NEARBY_PROCESSING=on`. The server needs a key first (it has one in Docker).
3. **Add a computer** (step 2), once for each computer:
   - On Docker's **default bridge network** (a plain `-p 8787:8787`), the server can't find computers by itself: type each computer's address under **Your computer's address** and choose **Find**, or list them in `RAY_NEARBY_DEVICES` (for example `192.168.1.20,192.168.1.21`). On Windows the address is in Settings > Network & internet > your network > IPv4 address; on a Mac, System Settings > Wi-Fi (or Network) > Details > IP address.
   - With **host networking** or **macvlan**, computers where Ray is open show up under **Found on your network** by themselves (see [Bridge or host networking](#bridge-or-host-networking)).
4. **Approve it on the computer** (step 3): choose **Use this computer**. On that computer a box called **Allow Ray Nearby?** appears: tick **Always allow this device** and choose **Allow**. Without the tick the approval ends when that computer restarts. Didn't see it? Choose **Ask again**.
5. **Choose where jobs run** (the tab asks once; later **Where jobs run**):

   | Dashboard | `run_on` | What happens |
   |---|---|---|
   | **My computers when free** (recommended) | `auto` | A job goes to one of your computers when one is free, and whenever this server can't run it itself. Otherwise it runs here. |
   | **Only my computers** | `devices` | Jobs wait until a computer takes them. |
   | **This server only** | `server` | Jobs run here, unless a job or a watch folder asks otherwise. |

   `RAY_NEARBY_RUN_ON` sets it at startup. A single job (**Where it runs** on Create, `"run_on"`, `ray-cli api submit --run-on`), a watch folder and a connection can choose for themselves.

### What goes to your computers

- Only jobs that **create subtitles** (with or without a translation). Burn-in, ReTime and jobs with several steps always run on the server.
- The server first looks for an existing subtitle itself. A computer is used only when new subtitles have to be made.
- A computer gets the **audio** of the video (the chosen track, never the picture) and its **file name**. With Ray 4.0.16 or later there, the computer deletes the audio when the job ends, and the subtitles it made and its copy of the job once the server has them (an hour after the job ends if the server never collects them). Audio the server stopped sending partway goes 15 minutes after the last of it arrived. Ray before 4.0.16 keeps a copy of each subtitle and the audio for at least a day, so update Ray on your computers. Jobs from everyone who uses the server can run on your computers, so those computers see their file names.
- The first job on a computer takes longer while Ray there sets itself up; job rows say what each computer is doing ("Made on Studio PC" when done). With Ray 4.0.16 there, the graphics card in a computer's name is the one Ray Local uses on it, unless you gave it a name of your own.
- A job that may run only on your computers fails after two failed attempts there - or, when it allows Ray Cloud, continues there (also after 30 minutes without a free computer). **Retry on this server** runs a failed one here.

Good to know:

- Sending jobs to computers only makes connections from the server outwards: no extra ports to publish.
- The server keeps its own device key in `/config`. Anyone with a copy of `/config` could use the computers that trust this server, so keep it private; if a copy leaks, remove this server under **Always allowed** in Ray's **Settings > Processing** on each computer.
- Keep the server's clock right (most NAS systems do this by themselves): Ray ignores device messages more than 5 minutes off.
- Turning **Use your devices** off stops at once: jobs on a computer come back to the server's queue.

### Take work from your devices

The other way round: with **Use your devices** on, an owner can also turn on **Take work from your computers** in the same tab (or `RAY_NEARBY_RECEIVE=on`). Ray on a busy computer then sends its next job to the server, which makes the subtitles and sends them back.

It needs:

- the container **directly on your network**: host networking or macvlan (not Docker's default bridge network);
- the server connected to your Ray account and able to make subtitles with Ray Local;
- the NAS firewall, if it has one, to let your network in on TCP ports **8788-8798** and UDP port **8791**;
- no other Ray on the same machine taking work (a second server with host networking, or a Ray desktop app on the same computer, shares UDP port 8791).

To connect a computer: on it, open Ray > **Settings > Processing**, find the server under **Your Nearby Pool** and choose **Connect**. Then allow it in the dashboard within 2 minutes (tick **Always allow** to keep it). The file a computer sends, and the subtitles Ray makes from it, stay in `/data` only until its job ends (a file that stopped arriving partway goes 15 minutes after the last of it arrived). The result waits in a hidden `.ray-work` folder in `/out` until the computer collects it, for a day at most; neither lands among your results.

A computer's **Send to** (sending a whole file to another device) doesn't work with a Ray server; add media from the dashboard instead.

---

## Bridge or host networking

| | Default bridge network (`ports: - "8787:8787"`) | Host networking (`network_mode: host`) or macvlan |
|---|---|---|
| Dashboard | `http://SERVER-IP:8787/` (the port you published) | `http://SERVER-IP:8787/` (`ports:` is ignored) |
| Finding your computers (Your devices, app sign-in) | type their addresses (or list them in `RAY_NEARBY_DEVICES`); for app sign-in also set `RAY_NEARBY_LAN_SUBNETS` | found by themselves |
| Take work from your computers | not available | works (open TCP 8788-8798, UDP 8791) |
| Two Ray servers on one machine | fine | each needs its own port; only one can take work |

Host networking is for a Linux Docker host (most NAS systems). Compose:

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    network_mode: host          # replaces the ports: block
    environment:
      RAY_DEVICE_NAME: "Living room NAS"   # the name your computers show for this server
```

On a NAS GUI: Synology Container Manager **Network > host**; Unraid **Network Type: Host** (or **Custom: br0** for macvlan); QNAP Container Station **Host** (or **Bridge**, which gives the container its own address on your network).

On the bridge network, set `RAY_DEVICE_NAME` (or `hostname:`) so Ray on your computers shows a name you recognize when this server asks it to approve a sign-in, instead of the container id. (In the Use your devices lists the server is called "Ray Server" and what it runs on, unless `RAY_DEVICE_NAME` is set.)

---

## Ray Local on small servers

Before each job Ray Local checks whether this server can run the quality you picked **right now**:

- **Free memory, not total memory.** A 16 GB NAS with 3 GB free counts as a 3 GB machine. With ZFS (TrueNAS SCALE, Proxmox, Unraid with ZFS) the ZFS cache can hold most of the memory and doesn't count as free: cap it in the host's ZFS settings if Ray Local keeps saying there isn't enough memory. Don't set a container memory limit below the free memory.
- **Graphics.** A separate graphics card is used when the container can reach it. Integrated and Intel graphics are not: Ray Local runs on the processor there. `RAY_LOCAL_PROCESSOR=cpu` makes Ray Local always use the processor.

When the quality you picked doesn't fit but a lighter one does, the job runs the lighter one and says so ("Switched from Sunlight to fit this server"). When nothing fits, the job fails with `local_unsupported` and a reason:

| Reason | What to do |
|---|---|
| `free_memory` | Pick a lighter quality, free up memory (see the ZFS note), or use Ray Cloud. |
| `graphics` | Close other apps that use the graphics card, use the `cpu` image for integrated or Intel graphics, fix the device access the log names, or use Ray Cloud. |
| `unsupported` | Use Ray Cloud, or try again later. |

A watch folder or connection with **Use Ray Cloud if Ray Local can't** continues in Ray Cloud instead of failing, and [your devices](#use-your-devices-nearby-processing) can make the subtitles when this server can't.

---

## One-shot mode

Subtitle one file and exit, no long-running server:

```sh
docker run --rm \
  -v ray-config:/config -v ray-models:/models -v ray-data:/data \
  -v "$PWD/out:/out" -v "$PWD/media:/media:ro" \
  techspecs/ray:cpu generate /media/movie.mkv --language es --quality best
```

Next to a running server, a one-shot run uses the server's user by itself: without `PUID` / `PGID` it runs as the owner of `/config`, and it never takes `/config`, `/models`, `/data` or `/out` away from another user. If you set `PUID` / `PGID` here, use the same values as your server.

The subtitle is saved in `/out` named after the video (`movie.es.srt`). Options: `--language CODE`, `--quality fast|best`, `--format srt|vtt|json`, `--output FILE` (an extra copy), `--audio-track ID` or `--audio-language CODES`. `tracks FILE` lists a video's audio and subtitle tracks.

`generate` runs its own private server inside the container (loopback port `18787`, `RAY_GENERATE_PORT`) that nothing outside can reach, and never touches watch folders, so it is safe to share `/config` with a running server.

---

## Removing finished jobs

The Jobs list is kept while the server runs and starts empty after a restart (saved files stay where they are). **Remove** a finished job, or **Clear finished** (completed, failed and canceled jobs; running jobs are never touched). Both ask first, with **Also delete the result files from the server** (off by default). Only files Ray made for those jobs are deleted, and only while unchanged: your videos, subtitles you provided and files changed since are always kept. Removing a watch folder job doesn't make the folder process that video again.

Over HTTP: `DELETE /v1/jobs/{id}?delete_result=1` and `POST /v1/jobs/clear?delete_results=1`.

---

## Volumes

| Mount | What it holds | Keep it? |
|---|---|---|
| `/config` | Settings: the server's Ray account connection, keys, watch folders, connections, and the device key for Your devices. **This is your seat.** | **Yes**, and keep it private |
| `/models` | What Ray downloads to make subtitles (several GB) | Yes, or it downloads again |
| `/data` | Working data | yes |
| `/out` | Finished results, named after the video. Work in progress sits in a hidden `.ray-work` folder inside it. | your output |

Media is mounted too and submitted by its **in-container** path (`/media/...`). Read-only (`:ro`) keeps every result in `/out`; read-write lets Ray save subtitles next to your videos.

---

## Running as your NAS user (PUID, PGID, UMASK)

Ray runs as user `1000`, group `1000` unless you choose otherwise. Set `PUID` and `PGID` to your own account so everything Ray writes belongs to you, and your file manager, Plex, Jellyfin or Emby can use it:

```sh
docker run -d --name ray-server -p 8787:8787 \
  -e PUID=1026 -e PGID=100 -e UMASK=002 \
  -v /volume1/docker/ray/config:/config \
  -v /volume1/docker/ray/models:/models \
  -v /volume1/docker/ray/data:/data \
  -v /volume1/docker/ray/out:/out \
  -v /volume1/video:/media \
  techspecs/ray:cpu
```

Find your ids by running `id` on the NAS (over SSH, as your own user):

| NAS | Typical `PUID` | Typical `PGID` |
|---|---|---|
| Synology | `1026` (the first user you created) | `100` (users) |
| Unraid | `99` (nobody) | `100` (users) |
| QNAP | `1000` (the first user you created) | `100` (everyone) |

What happens at start:

- The container starts as root only long enough to prepare Ray's own folders, then switches to `PUID`:`PGID`. The log says `running Ray as user 1026, group 100`.
- `/config`, `/models` and `/data` are given to that user (only entries with another owner, so later starts are quick). Folders Docker created as root for a missing bind mount are fixed too.
- `/out` is made writable for that user when it isn't already.
- **Your media folders are never changed.** Make sure `PUID` can read them, and write to them for library mode.
- `UMASK` sets the permissions of new files: `022` gives `rw-r--r--`, `002` lets everyone in `PGID` edit them.
- Changing `PUID` / `PGID` later is fine: Ray's folders move to the new user at the next start, and your keys and sign-in are kept.

Good to know:

- `docker exec` runs as root unless you say otherwise: use `docker exec -u 1026:100 ray-server ray-cli ...`.
- **Extra containers on the same volumes** (`login`, `generate`, `tracks`, a second `watch` container): give them the same `-e PUID=... -e PGID=...` as your server. Every start of the image gives `/config`, `/models` and `/data` to its `PUID` / `PGID` (default `1000:1000`), so a run with other ids takes those folders away from the running server until it restarts.
- Started with `--user 1026:100`, nothing is remapped and only `UMASK` applies; make the folders writable for that user yourself.
- Rootless Docker or Podman: set `PUID=0` and `PGID=0`.
- `RAY_SKIP_CHOWN=1` leaves folder owners as they are (for a huge model folder on a share the user can already write).
- The start needs Docker's default `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID` and `SETGID` capabilities; with `--cap-drop ALL`, add those five back or use `--user`.

---

## GPU passthrough

- **`cuda`**: install the NVIDIA Container Toolkit on a Linux host and run with `--gpus all`; on Windows, Docker Desktop with WSL2 and `--gpus all`. Compose:

  ```yaml
      deploy:
        resources:
          reservations:
            devices:
              - driver: nvidia
                count: all
                capabilities: [gpu]
  ```

- **`vulkan`** (a separate AMD card, Linux host): `--device /dev/dri --device /dev/kfd` (compose: `devices: ["/dev/dri:/dev/dri", "/dev/kfd:/dev/kfd"]`). `/dev/kfd` lets Sunlight separate voices from the background sound on the graphics card; without it the subtitles are made from the full soundtrack and each job says so. The first such job prepares the card, which can take several minutes; later jobs start right away. Ray adds the groups of the passed-in devices by itself, so no `--group-add` is needed (only with `--user`: `--group-add "$(stat -c %g /dev/dri/renderD128)"`).
- **Integrated or Intel graphics:** use `cpu` and don't pass `/dev/dri`.

The server card on **Create** says what Ray Local runs on, and when a graphics device was passed in but can't be used (the container log says the same at start, with the fix).

---

## TLS and reverse proxies

The server speaks plain HTTP on 8787. For HTTPS, put it behind your reverse proxy (Caddy, nginx, Traefik, Nginx Proxy Manager) like other self-hosted apps, and don't send keys over untrusted plain HTTP.

The server stays private behind the proxy: on Docker's bridge network every request needs a key. When Ray listens only on loopback on the same machine as the proxy (`network_mode: host` with `RAY_DEVAPI_EXPOSE=0`, or a `ray-server` installed on the host), set `RAY_REQUIRE_AUTH=1` so proxied requests still need a key. Ray never grants access because of `Forwarded`, `X-Forwarded-For` or `X-Real-IP` headers.

For **Sign in with your Ray app** behind a proxy: keep the proxy's forwarding headers on (if you can't, set `RAY_APP_SIGNIN=off`), and add the name you use to `RAY_PUBLIC_HOSTNAMES` (a comma list) or set `RAY_PUBLIC_URL` (for example `https://ray.example.com`), which also makes sign-in links start with that address. Addresses, one-word names like `nas`, and `.local`, `.lan`, `.home.arpa` and `.internal` names work without it. A proxy on another machine or in another container counts as one visitor for the sign-in limits until you name it in `RAY_TRUSTED_PROXIES` (its address, or its Docker network like `172.18.0.0/16`). A request from outside your network (including Tailscale addresses) is never offered app sign-in; use a key or a sign-in link.

---

## Environment variables

The most useful ones. `docker run --rm techspecs/ray:cpu ray-server --help` lists all of the server's own; `PUID`, `PGID`, `UMASK`, `RAY_SKIP_CHOWN` and `RAY_GENERATE_PORT` belong to the container's start and are described here.

| Variable | Default | What it does |
|---|---|---|
| `PUID` / `PGID` | `1000` / `1000` | User and group Ray runs as. |
| `UMASK` | `022` | Permissions of new files (`002`: your group can edit them). |
| `RAY_SKIP_CHOWN` | unset | `1` leaves the owners of `/config`, `/models`, `/data` and `/out` as they are. |
| `RAY_ACCOUNT_EMAIL` / `RAY_ACCOUNT_LICENSE_KEY` | unset | Connect the server to a Ray account without signing in interactively. |
| `RAY_DEVAPI_KEY_HASH` | unset | Owner keys by SHA-256 hash (`sha256hex[:prefix]`, comma-separated). Remove one and restart to revoke it. The hash, never the key: an entry that starts with `ray_` is skipped. While it is set, no first owner key is made. |
| `RAY_DEVAPI_GENERATE_KEY` | `1` | `0`: don't make the first owner key. |
| `RAY_DEVAPI_EXPOSE` | `1` | Listen on the network. It still needs at least one key, otherwise the server stays on loopback. |
| `RAY_REQUIRE_AUTH` | automatic | Private mode. On by itself when the server is reachable from the network; `1` also on loopback (reverse proxy on the same machine), `0` off. |
| `RAY_MEMBER_JOBS` | `own` | What members see: `own` or `all` jobs. |
| `RAY_BROWSE` | unset (on) | Who may [browse the server's folders](#browse-the-servers-folders) (**Browse**, the suggestions while you type a path, `ray-cli api browse` and MCP apps): `on` (owners, and members within their **Can browse**), `owners` (owners only) or `off` (nobody; owners can still manage the favorite folders). It never changes which files members may use for jobs. Any other value stops the server with a message. |
| `RAY_MCP_LISTENER` | on | `0`, `false`, `off` or `no` (any case) turns off the connection for MCP apps at `/v1/mcp`; everything else keeps working. Recreate the container after changing it (see the [MCP guide](mcp.md#turning-it-off)). |
| `RAY_OUTPUT` | unset | Where results go by default: `out` or `beside` (next to the video). Unset: `out` for dashboard and API jobs, `beside` for watch folders. Sonarr and Radarr connections keep their own setting. |
| `RAY_OUTPUT_LANGUAGE_CODES` | `regional` | `regional` (`en`, `pt-BR`, `zh-Hant`) or `short` (two letters only). |
| `RAY_AUDIO_LANGUAGE` | unset | Preferred audio language(s) for videos with several tracks, in order (`ja,en`). |
| `RAY_LOCAL_PROCESSOR` | unset | `auto` or `cpu` (always the processor). |
| `RAY_WATCH_DIRS` / `RAY_WATCH_LANGS` | unset | Watch folders and their languages (languages required). |
| `RAY_WATCH_CONFIG` | unset | Per-folder watch settings as JSON (see [Watch folders](#from-the-command-line-or-the-environment)). |
| `RAY_WATCH_EDITABLE` | editable | `0` locks the watch folder list. |
| `RAY_CONNECTIONS` | unset | Sonarr and Radarr connections as JSON. |
| `RAY_CONNECTIONS_EDITABLE` | editable | `0` locks the Connections list. |
| `RAY_NEARBY_PROCESSING` | unset | `on` / `off` locks **Use your devices**. Unset: the owner decides (off by default). |
| `RAY_NEARBY_RUN_ON` | unset | Where jobs run by default: `server`, `auto` or `devices`. |
| `RAY_NEARBY_DEVICES` | unset | Your computers' addresses (`192.168.1.20,192.168.1.21`), for the bridge network. |
| `RAY_NEARBY_RECEIVE` | unset | `on` / `off` locks **Take work from your computers**. |
| `RAY_NEARBY_LAN_SUBNETS` | unset | Your home network (`192.168.1.0/24`), so a Ray app you type the address of can approve a sign-in from Docker's bridge network. Computers there may also answer the server's search for your devices. |
| `RAY_NEARBY_WORKER_SUBNETS` | unset | Other private networks whose computers may send work here. |
| `RAY_DISABLE_NEARBY_FANOUT` | unset | `1` keeps every job on this server. Older images set it themselves: remove it to use your devices. |
| `RAY_DEVICE_NAME` | unset | The name your Ray apps show for this server. Unset: the host name when they approve a sign-in (in a container, its id), and "Ray Server" plus what it runs on in their Use your devices lists. |
| `RAY_TELEMETRY` | on | `off` turns crash reporting off. |
| `RAY_GENERATE_PORT` | `18787` | Loopback port of the one-shot `generate` server. |
| `RAY_OWNER_EMAIL` | unset | With `RAY_APP_SIGNIN` `on` or `local`: the Ray account that may set up a server that isn't connected yet with **Sign in with your Ray app**, no key needed. No effect while app sign-in is off, or once the server is connected. |
| `RAY_APP_SIGNIN` | unset (off) | **Sign in with your Ray app**: `on`, `local` (this network only, no proxy) or `off`. Unset: off until an owner turns it on in People. Set: People can't change it. |
| `RAY_PUBLIC_HOSTNAMES` | unset | Other names the dashboard is opened under (behind a proxy), comma-separated. App sign-in only answers under a name the server knows. |
| `RAY_PUBLIC_URL` | unset | The address people use (`https://ray.example.com`): sign-in links start with it, and its name counts as one of `RAY_PUBLIC_HOSTNAMES`. |
| `RAY_TRUSTED_PROXIES` | unset | Your reverse proxy's addresses or networks (`172.18.0.0/16`), comma-separated, so the sign-in limits count each visitor instead of the proxy. |

---

## API and ray-cli

Everything the dashboard does goes through the Ray Developer API under **`/v1`**, with the key as a Bearer token. (Images from this release on also answer the same routes under `/v4`; `/v1` works on every image.)

```sh
KEY=ray_...    # your key
curl -H "Authorization: Bearer $KEY" http://SERVER-IP:8787/v1/jobs

curl -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"file_path":"/media/Movie.mkv","target_language":"en","output":"beside"}' \
  http://SERVER-IP:8787/v1/subtitles
```

Times in API answers are ISO 8601 in UTC (`2026-09-27T14:03:11Z`).

A subtitle file given as `file_path` for a job that needs the video's sound (making subtitles, ReTime, burn-in) is refused with `400` and `subtitle_file_not_media`. To translate it, send `"subtitle_source": "translate"` with `subtitle_path` set to that file and a `target_language`.

**ray-cli** is in the image (`docker exec -u 1000:1000 -e RAY_API_KEY=ray_... ray-server ray-cli api jobs`, with your `PUID`:`PGID`) and installs on its own, without the server ([Install only the CLI](../README.md#install-only-the-cli)). Point it at a server with `RAY_API_URL=http://SERVER-IP:8787` and `RAY_API_KEY=ray_...`; an address without `/v1` or `/v4` gets `/v1`. `RAY_API_KEY` is `ray-cli`'s setting, the key it sends: the server never reads it, and takes its own keys from the first start, **People** or `RAY_DEVAPI_KEY_HASH`. Useful commands: `api submit FILE --language en [--wait]`, `api jobs`, `api download JOB_ID`, `api tracks FILE`, `api browse [FOLDER]`, `api favorites`, `api keys`, `api devices`, `api connections`.

**MCP apps:** the server also answers apps that speak MCP (the Model Context Protocol) at `/v1/mcp`, behind the same keys, so Cursor and similar apps can make, translate and read subtitles here. `ray-cli api mcp` connects an app that starts a command (in Docker: `docker exec -i -u 1000:1000 ray-server ray-cli api mcp`, with your `PUID`:`PGID`); `RAY_MCP_LISTENER=0` turns it off. Set-up for each app: [MCP guide](mcp.md).

---

## Upgrading from an earlier image

Pull the new image and recreate the container; `/config`, `/models` and `/data` carry over:

```sh
docker compose pull && docker compose up -d
```

Coming from **4.0.15-beta.1 or earlier**, note:

- **Ray now runs as `PUID`:`PGID` (default `1000:1000`) and gives `/config`, `/models` and `/data` to that user at start.** If you had made those folders belong to another account (and writable for everyone), set `PUID` / `PGID` to that account. Started with `--user`? Nothing changes.
- **Results are named after the video** (`Movie.en.srt`), not after the job id, with two-letter language codes whenever the language has one (`Movie.nl.srt`, and `Movie.zh.srt` for Chinese rather than `.cmn`). Files from earlier images are left as they are.
- **Watch folders save next to the videos by default** (library mode). That needs the media mounted read-write; with `:ro` they keep going to `/out`, and each job says why. Set `RAY_OUTPUT=out` (or give the folder `"output":"out"`) to keep the old behavior without the note.
- **The dashboard is private**: it asks you to [sign in](#signing-in) before it shows anything.
- **Remove `RAY_DISABLE_NEARBY_FANOUT` from the container's environment** if it is still there. Older images set it themselves, and some container managers keep it when you update; while it is set, every job stays on the server and Use your devices can't send jobs anywhere.
- **Members you already had keep every folder they could use** and show as **Everywhere** under **Can browse** in [People](#private-dashboard-people-and-keys) (this happens once, at the first start of 4.0.16). People you add from now on start at **Favorites only**: until an owner saves a favorite folder they may use, they can only upload files.
- **The one-shot `generate` server moved to port `18787`** (from `8788`, which Ray apps on the same machine use).
- **API times are UTC** with a `Z` (`2026-09-27T14:03:11Z`) instead of the server's local time without an offset.
- **ray-cli keeps a server address that ends in `/v1` or `/v4`**, and adds `/v1` to one without a version, so the same ray-cli works with older and newer servers.

---

## Tags

- `techspecs/ray:cpu`, `techspecs/ray:cuda`, `techspecs/ray:vulkan` - the latest release of each image.
- `techspecs/ray:<version>-<variant>` (for example `4.0.16-beta.1-cpu`) - a fixed release you can pin.

---

## Notes

- **Your seat:** one server = one seat, the same pool as the desktop app. The seat lives in `/config`: recreating the container keeps it, deleting the volume doesn't. Running many containers from *copies* of one `/config` uses more seats.
- **Cold start:** the first job downloads what Ray needs into `/models` (several GB); progress shows in the Jobs list and `docker logs`.
- **Health:** the image has a Docker health check on `/v1/health`.
- **Telemetry:** crash reporting is on by default; `RAY_TELEMETRY=off` turns it off.
- **Updates:** images are fixed; update by pulling a newer tag. There is no in-app updater in the container.
