# Ray headless on a NAS - step by step

A plain-English guide to running Ray on a NAS (Synology, QNAP, Unraid, TrueNAS) or any always-on box. If you can install an app on your NAS, you can do this. No Docker knowledge needed: copy the blocks, change the parts we point out, done.

When you're finished you'll have:

- a dashboard in your browser to make subtitles for any video on the NAS,
- subtitles saved **next to your videos**, where Plex, Jellyfin and Emby find them,
- optionally: folders that subtitle themselves, Sonarr and Radarr sending every new episode and movie, your family with their own access, and your PC's graphics card doing the heavy lifting.

**Contents:** [What you'll need](#what-youll-need) · [1. Terminal](#step-1---open-a-terminal-on-your-nas) · [2. Your user id](#step-2---find-your-user-id-puid-and-pgid) · [3. Compose file](#step-3---make-a-folder-and-the-compose-file) · [4. Start](#step-4---start-ray) · [5. Sign in](#step-5---sign-in) · [6. First subtitles](#step-6---your-first-subtitles) · [Next to your videos](#subtitles-next-to-your-videos-plex-jellyfin-emby) · [Watch folders](#subtitle-whole-folders-automatically-watch-folders) · [Sonarr and Radarr](#sonarr-and-radarr) · [People](#give-your-family-their-own-access-people) · [Audio tracks](#videos-with-several-audio-tracks) · [Ray Cloud](#use-ray-cloud) · [Your PC's graphics card](#use-your-pcs-graphics-card-your-devices) · [Updating](#updating-ray) · [Where your data lives](#where-your-data-lives) · [File ownership](#file-ownership--permissions) · [Different port](#using-a-different-port) · [Troubleshooting](#troubleshooting) · [GPU](#gpu-acceleration)

---

## What you'll need

- A NAS or server with a **64-bit Intel or AMD processor** that can run **Docker** (containers). Synology DSM 7.2 or later has **Container Manager**; DSM 6.2 can use the Docker package and the terminal command in step 4. QNAP, Unraid and TrueNAS SCALE also work. Ray doesn't run on NAS boxes with an ARM processor yet; your NAS maker's specification page names the processor.
- About **10 GB of free space** for what Ray downloads the first time.
- Your **Ray account** (the same one you use in the Ray app).
- Handy: **Ray open on a Windows PC or Mac** on the same network, signed in to your Ray account, to connect the NAS to that account with one approval. (Without one, an emailed code does it.)
- Your NAS's **IP address** on your network, like `192.168.1.50`. Your NAS's control panel shows it (Synology: Control Panel > Network > Network Interface; QNAP: Control Panel > Network & Virtual Switch; Unraid: top of the dashboard), and so does your router's list of devices.

> Most NAS boxes have no graphics card Ray can use, so this guide uses the **`cpu`** image, which needs no graphics card. Have an NVIDIA card or a separate AMD card in the box? See [GPU acceleration](#gpu-acceleration). Have a PC with a graphics card on your network? See [Use your PC's graphics card](#use-your-pcs-graphics-card-your-devices).

---

## Step 1 - Open a terminal on your NAS

A few steps use commands. You type those in a **terminal** on the NAS:

- **Synology:** Control Panel > **Terminal & SNMP** > tick **Enable SSH service**. On your computer open **PowerShell** (Windows) or **Terminal** (Mac) and run `ssh your-user@YOUR-NAS-IP`. Docker commands need `sudo` in front.
- **Unraid:** click the **`>_`** icon at the top right of the web dashboard: a terminal opens in your browser.
- **QNAP:** Control Panel > **Network & File Services** > **Telnet / SSH** > enable SSH, then `ssh admin@YOUR-NAS-IP` from your computer.
- **TrueNAS SCALE:** System > **Shell**.
- **Your own PC (not a NAS):** open **PowerShell** (Windows) or **Terminal** (Mac); Docker commands run there directly.

---

## Step 2 - Find your user id (PUID and PGID)

Ray should write files as **you**, so your file manager, Plex, Jellyfin and Emby can use them. For that it needs your user id and group id. In the terminal, **as your own user** (not root), run:

```sh
id
```

You'll see something like:

```
uid=1026(alex) gid=100(users) groups=100(users),101(administrators)
```

The number after `uid=` is your **PUID** (here `1026`), the number after `gid=` is your **PGID** (here `100`). Write them down.

Typical values, if you can't run `id`:

| NAS | PUID | PGID |
|---|---|---|
| Synology | `1026` (the first user you created) | `100` (users) |
| Unraid | `99` (nobody) | `100` (users) |
| QNAP | `1000` (the first user you created) | `100` (everyone) |

---

## Step 3 - Make a folder and the compose file

**1. Make a folder for Ray** on your NAS:

| NAS | Folder |
|---|---|
| Synology | `/volume1/docker/ray` (File Station > `docker` > Create folder `ray`) |
| Unraid | `/mnt/user/appdata/ray` |
| QNAP | `/share/Container/ray` |
| Anything else | any folder, like `~/ray` |

**2. Find the folder with your videos** (your library), as the NAS sees it. For example `/volume1/video` (Synology), `/mnt/user/media` (Unraid), `/share/Multimedia` (QNAP).

**3. Create a file called `compose.yaml`** in Ray's folder with this content. Change the three lines marked `<-`:

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    container_name: ray-server
    ports:
      - "8787:8787"
    environment:
      PUID: "1026"      # <- your PUID from step 2
      PGID: "100"       # <- your PGID from step 2
      UMASK: "002"      # your group can edit the files Ray writes
    volumes:
      - ray-config:/config
      - ray-models:/models
      - ray-data:/data
      - ./out:/out
      - /volume1/video:/media    # <- your video folder on the left, keep /media on the right
    restart: unless-stopped

volumes:
  ray-config:
  ray-models:
  ray-data:
```

Use the code block's copy button and save it as plain text. The first line of the saved file must be `services:`. If it starts with `{`, it is not the Compose file above; copy the YAML block again. Do not include the code fence lines in the file.

What the lines mean:

| Line | Meaning |
|---|---|
| `image: techspecs/ray:cpu` | The Ray image for any NAS with an Intel or AMD processor; no graphics card needed. |
| `"8787:8787"` | The dashboard's port. Only change the **first** number, if 8787 is taken (see [Using a different port](#using-a-different-port)). |
| `PUID` / `PGID` / `UMASK` | Who owns the files Ray writes (see [File ownership](#file-ownership--permissions)). |
| `ray-config`, `ray-models`, `ray-data` | Ray's own storage: your sign-in and settings, what it downloads, working data. **Keep them.** |
| `./out:/out` | Finished subtitles that aren't saved next to a video show up in the `out` folder beside this file. |
| `/volume1/video:/media` | Your videos. Inside Ray they are under `/media`: a movie at `/volume1/video/Movies/Up.mkv` is `/media/Movies/Up.mkv` to Ray. |

> **Read-write or read-only?** As written, Ray can **save subtitles next to your videos** (it never changes or deletes your videos, and never replaces a subtitle it didn't make). Prefer Ray to never write into your library? Add `:ro` at the end (`/volume1/video:/media:ro`): every subtitle then goes to the `out` folder instead.

**4. Let your user write to the video folder** (for subtitles next to your videos):

- **Synology:** Control Panel > **Shared Folder** > select the folder (for example `video`) > **Edit** > **Permissions** > your user: **Read/Write**.
- **QNAP:** Control Panel > **Privilege** > **Shared Folders** > the folder's **Edit Shared Folder Permission** > your user: **RW**.
- **Unraid:** shares are writable for `99:100` by default; nothing to do.

---

## Step 4 - Start Ray

Pick the way that fits your NAS.

### Any NAS with a terminal (works everywhere)

```sh
cd /volume1/docker/ray        # Ray's folder from step 3
sudo docker compose up -d
```

If your NAS has `docker-compose` instead, use `sudo docker-compose -f compose.yaml up -d` so it opens the file you made in step 3. If that older Compose version cannot read the file, use the Docker command below.

### Older Synology (DSM 6.2) without current Compose

On an older Synology (DSM 6.2) whose docker-compose is out of date, you can skip the compose file and run this instead. Change `1026` and `100` to your PUID and PGID from step 2, and change `/volume1/video` if your videos are elsewhere:

```sh
sudo docker run -d --name ray-server --restart unless-stopped -p 8787:8787 -e PUID=1026 -e PGID=100 -e UMASK=002 -v ray-config:/config -v ray-models:/models -v ray-data:/data -v /volume1/docker/ray/out:/out -v /volume1/video:/media techspecs/ray:cpu
```

No YAML file is needed. Get the first-start key with `sudo docker logs ray-server`, then open `http://<NAS-IP>:8787/` in your browser and continue at step 5. Do not start a second `ray-server` if you already started one with Compose.

### Synology (DSM 7.2 or later - Container Manager)

1. Open **Container Manager** > **Project** > **Create**.
2. **Project name:** `ray`. **Path:** Ray's folder from step 3 (`/docker/ray`).
3. **Source:** it finds your `compose.yaml` (or choose **Create docker-compose.yml** and paste it).
4. **Next** > **Next** > **Done**. Container Manager downloads Ray and starts it.

### Unraid

1. **Docker** tab > **Add Container** (at the bottom).
2. **Name:** `ray-server`. **Repository:** `techspecs/ray:cpu`. **Network Type:** Bridge.
3. **Add another Path, Port, Variable...** for each of these:

   | Type | Container | Host / value | Access |
   |---|---|---|---|
   | Port | `8787` | `8787` | |
   | Path | `/config` | `/mnt/user/appdata/ray/config` | Read/Write |
   | Path | `/models` | `/mnt/user/appdata/ray/models` | Read/Write |
   | Path | `/data` | `/mnt/user/appdata/ray/data` | Read/Write |
   | Path | `/out` | `/mnt/user/appdata/ray/out` | Read/Write |
   | Path | `/media` | `/mnt/user/media` (your share) | Read/Write (Read Only keeps subtitles in `/out`) |
   | Variable | `PUID` | `99` | |
   | Variable | `PGID` | `100` | |
   | Variable | `UMASK` | `002` | |

4. **Apply.**

### QNAP (Container Station 3)

1. **Container Station** > **Applications** > **Create**.
2. **Application name:** `ray`. Paste the `compose.yaml` from step 3 (with `/share/Multimedia:/media` or your folder). Change `./out:/out` to a full path such as `/share/Container/ray/out:/out`, so you know where the `out` folder is.
3. **Create.**

### TrueNAS SCALE (24.10 or later)

**Apps** > **Discover Apps** > the **⋮** menu > **Install via YAML**, name it `ray`, paste the `compose.yaml` (with your dataset path, like `/mnt/tank/media:/media`, and a full path for the `out` folder, like `/mnt/tank/apps/ray/out:/out` instead of `./out:/out`) and **Save**. Use PUID and PGID of the user that owns the media dataset.

**Check that it runs:** open the container's **log** (Synology: Container Manager > **Container** > `ray-server` > **Log**; Unraid: click the icon > **Logs**; QNAP: the container > **Logs**; terminal: `sudo docker logs ray-server`). You should see `running Ray as user 1026, group 100` and a box that says **Ray generated an API key for this server**. Leave the log open: you need that key in the next step.

---

## Step 5 - Sign in

The dashboard is **private**: only people who sign in see anything. The first time takes a few minutes:

**Copy the key**

1. Open the container's **log** (as in [step 4](#step-4---start-ray): Synology Container Manager > **Container** > `ray-server` > **Log**, Unraid's **Logs**, QNAP's **Logs**), or run this in the [terminal](#step-1---open-a-terminal-on-your-nas):

   ```sh
   sudo docker logs ray-server 2>&1 | grep -A3 "generated an API key"
   ```

   (Started it with `sudo docker compose up -d`? `sudo docker compose logs ray-server` in Ray's folder shows the whole log, each line starting with `ray-server` and a `|`.)
2. Find the box between two lines of `=====` that says **Ray generated an API key for this server**. Under it is one line that starts with `ray_`: that whole line is the key, `ray_` and 48 letters and digits. Copy it.

The key is shown **only this once**: Ray stores it hashed in `/config` and can't show it again, and recreating the container doesn't print it again. Keep it somewhere safe. Lost it? See [It asks for a key and I don't have one](#it-asks-for-a-key-and-i-dont-have-one).

**Sign in**

3. Open **`http://YOUR-NAS-IP:8787/`** in a browser (plain `http`, with the `/` at the end). The page says **Set up this Ray server**.
4. Paste the key into the field that says **Paste your API key**.
5. Under the button, **Keep me signed in on this browser** is ticked: this browser keeps the key until you sign out. Untick it first on a computer you share.
6. Choose **Sign in**. A message at the top right says **Signed in. Now connect this server to your Ray account.** If a short tour, **Get to know your Ray server**, opens, choose **Show me around** or **Skip tour**.

   "That key didn't work. Check it and try again."? Copy the whole line that starts with `ray_` again, and nothing else.

**Connect your Ray account** (with a code Ray emails you)

7. On the **Create** tab, find the card **This server's Ray account** and choose **Use an email code instead**.
8. A window, **Connect a Ray account**, opens. Type your Ray account's email under **Email** and choose **Send code**.
9. Ray emails you a 6-digit code. Type it under **Code from the email** and choose **Verify**. (Nothing came? Check the spam folder, or choose **Send a new code**. A typo in the address? Choose **Use a different email**.)
10. If your email can use more than one Ray account, the window says **Choose a Ray account**. Choose the one the NAS should use: **My own Ray account** is yours, a row with a name, like **Sam's Ray account**, is an account you belong to. A row that says "Waiting for ... to confirm you" can't be chosen yet.

**Check that it worked**

- A message at the top right says **Connected this server to** your email.
- The card **This server's Ray account** shows **Connected to** with your email, partly hidden.

Done: you're signed in as the owner, and the NAS is connected to your Ray account.

> **Rather approve on your computer than type a code?** In step 7, choose **Connect with your Ray app** (Ray open on your Windows PC or Mac, signed in to your Ray account). Under **Choose a device**, pick your computer. On it, check that the code matches the one on the dashboard and choose **Approve sign-in**. Back on the dashboard, **Connect this server to this Ray account?** shows the account: choose **Connect**. On Docker's normal (bridge) network this needs `RAY_NEARBY_LAN_SUBNETS` first (see [Your computer isn't in the list?](#your-computer-isnt-in-the-list)); until then, use the email code.

### Later: sign in with your Ray app (optional)

Rather approve on your computer than paste a key? In **People**, the **Sign in with your Ray app** tile is **Off**: choose **Turn on**. From then on the page says **Sign in to this Ray server**: choose **Sign in**, pick your computer, check that the code on your computer is the same as on the dashboard, and choose **Approve sign-in** there. It needs Ray 4.0.16 or later on that computer, signed in to the Ray account the NAS is connected to (as its owner), on the same network. **Use an API key instead** always works too.

#### Setting up a new NAS with the app

Ray is already running from step 4, so **copy the key first** (**Copy the key**, at the start of this step): when you start Ray again with a new setting, the log doesn't show the key again. The key keeps working. Then add this line to the compose file and start Ray again (`sudo docker compose up -d` in Ray's folder):

```yaml
    environment:
      RAY_APP_SIGNIN: "on"
```

Unraid has no compose file: edit the container, add a **Variable** `RAY_APP_SIGNIN` with the value `on`, and **Apply**. (Setting up from scratch? Add the line in [step 3](#step-3---make-a-folder-and-the-compose-file), before the first start.)

Then the first sign-in goes like this:

1. The page says **Set up this Ray server**. Paste the key into **Key from the server log**. On a computer you share, untick **Keep me signed in on this browser** (under the button). Then choose **Continue**.
2. The page says **Choose a device**. Pick your computer: Ray open on it, signed in to your Ray account.
3. The page says **Approve on** and your computer's name, with a code. On that computer, check that the code matches and choose **Approve sign-in**.
4. The page asks **Connect this server to this Ray account?** Check the account and choose **Connect and sign in**. A message says **Connected this server to** your account **and signed you in**: no email code needed.

**No computer in the list?** On the normal (bridge) network without `RAY_NEARBY_LAN_SUBNETS` (below), the page says "This server can't look for devices on your network by itself." At the bottom, after **No Ray app?**, choose **Continue with the key only**. A message says **Signed in with the key. This server isn't connected to a Ray account yet.** Then connect it with the email code: steps 7 to 10 above.

Add `RAY_OWNER_EMAIL: "you@example.com"` (your Ray account's email) as well, and no key is needed: until the NAS is connected, only that Ray account can set it up, and the page says **Set up this Ray server** with just **Continue**. Anyone who holds that account's license key could approve such a setup, so the key from the log is the safer way.

#### Your computer isn't in the list?

Choose **Enter an address** (under a list of computers it is the link **Enter an address instead**), type the computer's address under **Computer's address** (Windows: Settings > Network & internet > your network > IPv4 address; Mac: System Settings > Wi-Fi > Details > IP address), and choose **Send request**.

On Docker's normal (bridge) network, which the compose file in step 3 uses, first add your home network to the compose file and start Ray again (`sudo docker compose up -d`; Unraid: a **Variable** `RAY_NEARBY_LAN_SUBNETS`, then **Apply**). Without it the list stays empty and a typed address is refused with "That address isn't on this server's network.":

```yaml
    environment:
      RAY_NEARBY_LAN_SUBNETS: "192.168.1.0/24"   # your NAS address with its last number replaced by 0/24: NAS 192.168.1.50 -> 192.168.1.0/24
```

> **Keep the key somewhere safe** (a password manager). It is the **owner key**: it opens everything on this server. Don't share it; give other people [their own access](#give-your-family-their-own-access-people).

A key like this one (or a person's own key from **People**) also connects Cursor and other apps that speak MCP (the Model Context Protocol) to the NAS, so they can make and translate subtitles there: see the [MCP guide](mcp.md).

---

## Step 6 - Your first subtitles

1. On **Create**, choose **Use a server path** and type the video's path **inside Ray**: `/media/...` (for example `/media/Movies/Up (2009)/Up (2009).mkv`). Ray suggests folders and files as you type, or choose **Browse** to pick it.
2. Pick the **Subtitle language(s)**.
3. Tick **Save next to the video (for Plex, Jellyfin and Emby)**.
4. Choose **Create subtitles**.

Or drag videos from your computer onto the page (**Upload files**): each becomes its own job, and its subtitles go to the `out` folder (download them from **Jobs**).

Follow the job on **Jobs**. **The very first job takes a while**: Ray downloads what it needs (a few GB) once. Every job after that starts right away.

Want a tour? The **?** menu at the top replays the guided tours.

---

## Subtitles next to your videos (Plex, Jellyfin, Emby)

Plex, Jellyfin and Emby find a subtitle when it sits next to the video with the same name plus the language: `Up (2009).mkv` + `Up (2009).en.srt`. Ray does exactly that ("library mode") when:

- the video folder is mounted **read-write** (no `:ro`), and your `PUID` user may write there (see [step 3](#step-3---make-a-folder-and-the-compose-file));
- you tick **Save next to the video** (single jobs), or the watch folder or Sonarr / Radarr connection has **Save subtitles: Next to each video** (their default).

Ray **never replaces a subtitle it didn't make**. When it can't save next to the video (the name is taken, the folder is read-only or not writable, the file was uploaded, the language is unknown), the subtitle goes to the `out` folder and the job says why.

Names: `Movie.en.srt`, regional variants `Movie.pt-BR.srt`; in the `out` folder a taken name becomes `Movie (2).en.srt`, so nothing is overwritten. After a batch, let your media server rescan the library.

---

## Subtitle whole folders automatically (watch folders)

Ray can subtitle every video in a folder, and every new one that lands there, with no clicking.

1. Open **Watch folders** > **Add folder**.
2. **Folder on the server:** the folder **inside Ray**, like `/media/Movies` (not `/volume1/video/Movies`). Pick it from the suggestions as you type, or choose **Browse**; if you type the NAS's own path, Ray offers the one inside Ray when that folder is mounted.
3. **Subtitle language(s):** one file per language.
4. **Process with:** **Ray Local** (the NAS) or **Ray Cloud** (see [Use Ray Cloud](#use-ray-cloud)). On a small NAS, tick **Use Ray Cloud if Ray Local can't**.
5. **Save subtitles:** **Next to each video** (for Plex, Jellyfin and Emby).
6. **Also subtitle the videos already in this folder** - untick it to do only new arrivals.
7. **Add folder.**

No restart needed. A video that already has a subtitle in that language next to it is skipped; a subtitle without a language in its name (`Movie.srt`) counts for every language. **Pause**, **Edit** or **Remove** a folder from its row; removing keeps its history, so adding it back never redoes finished videos. Videos with several audio tracks: set **Audio language** (for example Japanese for anime).

Prefer settings in the compose file? See [watch folders from the environment](docker.md#from-the-command-line-or-the-environment).

---

## Sonarr and Radarr

Every episode or movie Sonarr or Radarr brings in gets subtitles right away. Sonarr and Radarr tell Ray through their built-in **Webhook** connection.

**Before you start:** know where your shows are **inside Ray**. If Sonarr keeps shows in `/volume1/data/media/tv` on the NAS and your compose file mounts `/volume1/data/media:/media`, Ray sees them at `/media/tv`. The media must be mounted **read-write** for subtitles next to the episodes.

### In Ray's dashboard

1. Open **Connections** > **Connect Sonarr**.
2. **Your shows on this server:** `/media/tv` (the folder inside Ray). Type it or choose **Browse**.
3. **Subtitle language(s):** for example English.
4. **Connect.** The card now shows a **Webhook URL** and a **Password**. **Copy the password right away** - it's shown only once.

The Webhook URL looks like `http://192.168.1.50:8787/v1/hooks/sonarr`: your NAS address, Ray's port, then `/v1/hooks/sonarr`. If Sonarr runs in the **same compose file** as Ray, use `http://ray-server:8787/v1/hooks/sonarr` instead. Never `127.0.0.1` or `localhost`: from Sonarr's container that means Sonarr itself.

### In Sonarr

1. **Settings** > **Connect** > the **+** tile > **Webhook**.
2. The Webhook screen, from top to bottom:

   | Field | What to enter |
   |---|---|
   | **Name** | `Ray` |
   | **Notification Triggers** | Leave them as they are (a new Webhook has almost all ticked). **On File Import** and **On File Upgrade** must be ticked. Ray also follows **On Import Complete**, **On Rename**, **On Series Delete**, **On Episode File Delete** and **On Episode File Delete For Upgrade**. |
   | **Tags** | Empty (all shows), or a tag to limit it to some shows. |
   | **Webhook URL** | Ray's Webhook URL |
   | **Method** | `POST` |
   | **Username** | empty |
   | **Password** | Ray's password |

3. Click **Test**. Ray's card changes to **Test received**.
4. Click **Save**.

**Radarr** works the same way: in Ray choose **Add a connection** > **Radarr** (or **Connect Radarr** while you have no connection yet) with your movies folder (`/media/movies`); in Radarr the delete boxes are called **On Movie Delete**, **On Movie File Delete** and **On Movie File Delete For Upgrade**.

**Good to know:**

- Only **new** episodes and movies get subtitles. For the ones you already have, add the same folder under [Watch folders](#subtitle-whole-folders-automatically-watch-folders).
- When Sonarr renames, upgrades or deletes an episode, Ray moves, redoes or removes **only the subtitles it made** (**Tidy up after Sonarr**, on by default).
- Sonarr sees the folder under another path (like `/tv`)? Ray learns it from the first episode and shows it as **Learned**. Details: [When Sonarr and Ray see different folders](docker.md#when-sonarr-and-ray-see-different-folders).
- Test fails? `[401:Unauthorized]` = wrong password; timeout = wrong address. More in [When something goes wrong](docker.md#when-something-goes-wrong).

---

## Give your family their own access (People)

Don't hand out your owner key. In **People**, choose **Add person** and type a name. Leave **Can manage this server** off for someone who only adds and follows their own jobs; turn it on for another owner.

- **With a sign-in link** (recommended): Ray makes a link. Send it to that person (a message, an email); they open it and choose **Continue as ...**. The link works once, within 24 hours, for one browser. They need no key and no Ray account.
- **With a key:** for scripts and the command line. Copy the key right away; it's shown once.

Everyone uses the server's Ray account for Ray Cloud. Members see only their own jobs (set `RAY_MEMBER_JOBS: "all"` to let them see every job), and can't pick files in Ray's own or system folders. **Send a new sign-in link** on a person's row gives them a link for another browser. **Remove person** in the row's **More** menu stops them at once: their key and links stop working, and every browser they're signed in on is signed out.

**Can browse** decides which of the NAS's folders a member can use: **Favorites only** (new people start here, with **All favorites**) or **Everywhere**. Save your media folders as favorites first, with the heart in **Browse**: a member set to **Favorites only** with no favorite can only upload files. Uploading always works. Details: [Browse the server's folders](docker.md#browse-the-servers-folders).

---

## Videos with several audio tracks

Anime with Japanese audio and an English dub, a film with a commentary track: Ray makes subtitles from one audio track.

- **One video:** on **Create** > **Use a server path**, an **Audio track** picker appears (like "Track 2 - Japanese"). Pick the one you want.
- **A folder, or many videos:** set **Preferred audio language** (Create), or **Audio language** on the watch folder or connection. When a video has no track in that language, Ray asks you in the Jobs list or uses the video's default, whichever you chose there.
- **Everywhere:** add `RAY_AUDIO_LANGUAGE: "ja,en"` to the compose file (first language that the video has wins).

---

## Use Ray Cloud

A small NAS can take a long time to make subtitles. **Ray Cloud** makes them on Ray's servers instead, with the server's Ray account; only the audio of the video leaves the NAS.

- **One video:** on **Create**, set **Run on** to **Ray Cloud**.
- **A watch folder or Sonarr / Radarr connection:** set **Process with** to **Ray Cloud**.
- **Only when the NAS can't:** keep **Ray Local** and tick **Use Ray Cloud if Ray Local can't**.

---

## Use your PC's graphics card (Your devices)

Most NAS boxes have no graphics card, but your PC might. Ray on the NAS can send the work of making subtitles to Ray on your computers and get the subtitles back. Jobs, watch folders and files stay on the NAS; a computer only gets the **audio** of each video and its file name, and with Ray 4.0.16 it keeps nothing once the NAS has the subtitles.

### On your PC (once)

1. Install or update the **Ray app (4.0.15 or later)** and sign in.
2. **Settings > Processing** > turn on **Available to Nearby devices**.
3. **Windows only:** set your network to **Private**: Settings > **Network & internet** > your Wi-Fi or Ethernet connection > **Network profile type** > **Private network**. On a Public network Windows blocks the NAS.
4. Give the PC a **fixed address** in your router (often called "DHCP reservation" or "static lease"), so the NAS always finds it at the same address. Note the address (Windows: Settings > Network & internet > your network > IPv4 address).

### On the NAS dashboard

1. Open **Your devices** and choose **Turn on** (step 1 of 3).
2. **Add a computer** (step 2 of 3):
   - With the normal compose file (Docker's **bridge** network), the NAS can't search your network by itself: type the PC's address under **Your computer's address** and choose **Find**. (Or add `RAY_NEARBY_DEVICES: "192.168.1.20"` to the compose file.)
   - With **host networking** (below), your PC shows up under **Found on your network** by itself.
3. Choose **Use this computer** (step 3 of 3). **On the PC**, a box called **Allow Ray Nearby?** appears: tick **Always allow this device** (otherwise the approval ends when the PC restarts) and choose **Allow**. Didn't see it? Choose **Ask again**.
4. Choose where jobs run: **My computers when free** is a good start (the NAS uses your PC when it's free, and does the job itself otherwise).

The **New here? Take the one-minute tour** link on the tab walks through it.

### Bridge or host network?

The normal compose file uses Docker's **bridge** network: everything above works, you just type your PCs' addresses. **Host networking** puts Ray directly on your network, so it finds your PCs by itself, and it's needed for the other way round (your PCs sending work to the NAS: **Take work from your computers**). To switch, replace the `ports:` lines with `network_mode: host`:

```yaml
services:
  ray-server:
    image: techspecs/ray:cpu
    container_name: ray-server
    network_mode: host                  # instead of "ports:"
    environment:
      PUID: "1026"
      PGID: "100"
      UMASK: "002"
      RAY_DEVICE_NAME: "Living room NAS"   # how your PCs name this server
    # volumes: as before
```

The dashboard stays at `http://YOUR-NAS-IP:8787/`. In a NAS GUI: Synology **Network > host**, Unraid **Network Type: Host**, QNAP **Host**. For **Take work from your computers**, a NAS firewall must let your network in on TCP ports **8788-8798** and UDP port **8791**. All details: [Use your devices](docker.md#use-your-devices-nearby-processing).

---

## Updating Ray

Your settings, sign-in and downloads are kept. In the terminal, in Ray's folder:

```sh
sudo docker compose pull
sudo docker compose up -d
```

- **Synology (Container Manager project):** the two commands above work in the project's folder (`/volume1/docker/ray`).
- **Synology DSM 6.2 with the `docker run` command:** run `sudo docker pull techspecs/ray:cpu`, then `sudo docker stop ray-server` and `sudo docker rm ray-server`. Run the same command from step 4 again, with your PUID, PGID and media path. Keep the named volumes; they hold your account and downloads.
- **Unraid:** Docker tab > **Check for Updates** > **apply update** on `ray-server`.
- **QNAP (Container Station application):** download the new image first (`sudo docker pull techspecs/ray:cpu`), then recreate the `ray` application in Container Station so it starts from the new image.

**Coming from 4.0.15-beta.1 or earlier?** Read [Upgrading from an earlier image](docker.md#upgrading-from-an-earlier-image) first: Ray now runs as `PUID`/`PGID` (default `1000`), names results after the video, and saves watch folder subtitles next to the videos. If your NAS kept `RAY_DISABLE_NEARBY_FANOUT` in the container's settings from an older version, remove it. Members you already added keep every folder they could use (**Everywhere** in **People**); people you add from now on start at **Favorites only**.

---

## Where your data lives

| Inside the container | What it is | Keep it? |
|---|---|---|
| `/config` | your sign-in, settings, keys, watch folders, connections | **Yes** - deleting it signs the server out. Keep it private. |
| `/models` | what Ray downloads to make subtitles (several GB) | **Yes** - otherwise it downloads again |
| `/data` | working data | yes |
| `/out` | finished subtitles that aren't next to a video | your output |
| `/media` | your videos (read-write: subtitles can go next to them; `:ro`: they all go to `/out`) | your files |

---

## File ownership & permissions

Ray runs as the `PUID` / `PGID` you set (default `1000` / `1000`), so everything it writes belongs to that user:

- At start, Ray's own folders (`/config`, `/models`, `/data`, and `/out` if needed) are given to that user. **Your media folders are never changed**: make sure that user can read them, and write to them for subtitles next to your videos.
- `UMASK: "002"` lets everyone in your group edit and delete the files Ray writes; the default `022` makes them read-only for the group.
- Changing `PUID` / `PGID` later is fine: Ray's folders move to the new user at the next start, and your sign-in is kept.
- Started with Docker's `--user` (or `user:` in compose) instead? Then nothing is changed for you: make the folders writable for that user yourself.

Details and special cases: [Running as your NAS user](docker.md#running-as-your-nas-user-puid-pgid-umask).

---

## Using a different port

Ray uses port **8787**. If something else already uses it (`port is already allocated`), change it. The port is written **`HOST:CONTAINER`**:

- the **first** number is the port on your NAS - **change this one**;
- the **second** is inside the container - **always leave it `8787`**.

Example for `8080`: compose `- "8080:8787"`, or `docker run -p 8080:8787`. Then open `http://YOUR-NAS-IP:8080/`. (With `network_mode: host` there is no mapping: the port stays 8787.)

---

## Troubleshooting

### The dashboard won't open

1. Use the right address: `http://YOUR-NAS-IP:8787/` - plain `http`, the **first** port number, a `/` at the end.
2. Check the container runs: `sudo docker ps` should list `ray-server` with `0.0.0.0:8787->8787/tcp` (your port on the **left**, `8787` on the **right**).
3. Check the NAS firewall allows the port.

### `port is already allocated` / `driver failed programming external connectivity`

Port 8787 is taken. [Use a different port](#using-a-different-port), or remove an old container (`sudo docker rm -f ray-server`) and find what holds the port (`sudo ss -ltnp | grep 8787`).

### It asks for a key and I don't have one

The key is printed in the container **log** the first time Ray starts, and only then (`sudo docker logs ray-server 2>&1 | grep -A3 "generated an API key"`, the line starting with `ray_`: see [Step 5](#step-5---sign-in)). Ray keeps only a fingerprint of it, so it can't show it again.

**Still signed in on a browser?** Open **People**. On the row called **Owner** (the key from the log), choose the **⋯** button, then **Replace their API key** and **Replace key**. Copy the new key with **Copy key**: it's shown only this once. The old key stops working at once.

**Signed out everywhere?** Make a new owner key: run these three lines in the NAS terminal (on a Windows PC, use the PowerShell lines in [Lost the key](docker.md#lost-the-key)), keep the printed key, and put the hash in the compose file:

```sh
KEY="ray_$(openssl rand -hex 24)"
echo "Your new key: $KEY"
printf %s "$KEY" | sha256sum | cut -d' ' -f1      # this is the hash
```

```yaml
    environment:
      RAY_DEVAPI_KEY_HASH: "paste-the-hash-here"
```

Then `sudo docker compose up -d` (Unraid: edit the container, add a **Variable** `RAY_DEVAPI_KEY_HASH` with the hash, and **Apply**). The log then says `imported 1 API key hash(es) from RAY_DEVAPI_KEY_HASH`. Sign in with the new key, and leave the line in the compose file. Your Ray account connection, People and settings in `/config` stay as they were.

- Don't delete the `ray-config` volume to get a new key: the next start would print one, but the volume also holds the NAS's Ray account connection (your seat), People, watch folders and connections.
- Paste the **hash** there, never the key itself. An entry that starts with `ray_` is the key: Ray skips it, and the log says so and shows how to make the hash. The whole line `sha256sum` prints (the hash, then `-`) is fine too.
- Keep the `ray_` at the start of the key: a key of 64 hex characters pasted there by mistake is taken as a hash, and then that key doesn't let anyone in.

### Settings can't be saved

The log warns that Ray can't save its settings, or signing in is refused because the settings can't be saved (`settings_not_writable`). The user Ray runs as can't write to `/config` (a folder owned by someone else, a read-only mount, or a network share that refuses ownership changes). Set `PUID` / `PGID` to the owner of that folder, or use a Docker **named volume** for `/config` (the compose file above does), then restart. Ray refuses to sign in while this is so, instead of forgetting the sign-in at the next start. If it continues, you can connect the account with `RAY_ACCOUNT_EMAIL` + `RAY_ACCOUNT_LICENSE_KEY` in the environment (the license key is shown with a copy button on the account screen of the Ray desktop app).

Until you fix it, this is what Ray does:

- **Works until the server stops:** your key, and signing in to the dashboard with it. While `/config` can't be saved and holds no key, every start prints a new owner key in the log, and its box says so: use the newest. Keys you set with `RAY_DEVAPI_KEY_HASH` work at every start, because they come from the compose file. A key you remove in **People** stays removed, and the installation ID in **Help** > **Copy diagnostics** stays the same, until the server stops. A Ray account set with `RAY_ACCOUNT_EMAIL` + `RAY_ACCOUNT_LICENSE_KEY` works too.
- **Refused, so nothing is lost at the next start:** connecting or disconnecting the server's Ray account (an emailed code or your Ray app), **Sign in with your Ray app**, sign-in links, and new keys in **People**. The page says why.
- **Lost when the container restarts:** whatever changed while it ran, and the watch folders' history. A key you removed comes back if it was saved before.

### The subtitles went to `out`, not next to my video

Open the job on **Jobs**: it says why. Usually the media is mounted `:ro`, your `PUID` user may not write in that folder ([step 3](#step-3---make-a-folder-and-the-compose-file)), a subtitle with that name already exists (Ray never replaces one it didn't make), or the video was uploaded rather than picked on the server.

### My subtitle is called `Movie (2).en.srt` or `Movie.mkv.en.srt`

`(2)`: a file with that name was already in the `out` folder; Ray never overwrites. `Movie.mkv.en.srt`: that folder has two videos with the same name (`Movie.mkv` and `Movie.mp4`), so each gets its own subtitles.

### A watch folder is refused or shows as missing

Use the path **inside Ray** (`/media/...`), in a folder you shared with the container in the compose file. Ray's own folders (`/config`, `/models`, `/data`, `/out`) are refused. For **Next to each video** the folder must be writable by your `PUID` user (or choose **In the output folder**). A folder on a network share that isn't mounted yet shows as missing and is picked up again when it's back.

### Sonarr's Test fails

`[401:Unauthorized]`: the password is wrong - copy it again, or make a new one on Ray's card. A timeout or "can't connect": wrong address - use the NAS IP and Ray's port (never `127.0.0.1`). `[409:Conflict]`: you used a Sonarr address in Radarr (or the other way round).

### The first job sits at "downloading" / "getting ready"

The first job downloads what Ray needs (several GB) into `/models`. It happens once. Keep the `ray-models` volume and make sure it has space.

### "Ray Local can't run this quality on this server right now"

Ray looks at the memory that is **free** right now, not the total. Pick a lighter quality (Moonlight), close other apps, or use [Ray Cloud](#use-ray-cloud) (watch folders: **Use Ray Cloud if Ray Local can't**). With ZFS (TrueNAS SCALE, Unraid with ZFS) the ZFS cache can hold most of the memory: limit it in the NAS's ZFS settings. With integrated or Intel graphics, use the `cpu` image.

### My PC doesn't show up in Your devices

On the normal (bridge) network the NAS can't search by itself: type the PC's address under **Your computer's address** and choose **Find**. On the PC, Ray must be open (4.0.15 or later) with **Available to Nearby devices** on, and on Windows the network must be **Private**. Keep the NAS clock right: Ray ignores device messages more than 5 minutes off.

### I chose "Use this computer" but nothing happens

Look at the PC: Ray shows **Allow Ray Nearby?** there. Tick **Always allow this device** and choose **Allow**. If it doesn't appear, choose **Ask again**. If jobs still never go to your computers, check that `RAY_DISABLE_NEARBY_FANOUT` isn't in the container's environment (older versions set it).

### "Sign in with your Ray app" can't find my computer, or says "That Ray account can't sign in here"

It's off until an owner turns it on in **People** (or sets `RAY_APP_SIGNIN`). Ray on your computer must be 4.0.16 or later, open, on the same network, and signed in to **the Ray account this server is connected to** as its owner (members of that account use a sign-in link; an older Ray is refused, and the page says to update it). On the bridge network, set `RAY_NEARBY_LAN_SUBNETS`, then choose **Enter an address** (or the link **Enter an address instead**), type the computer's address and choose **Send request** (see [Your computer isn't in the list?](#your-computer-isnt-in-the-list)). From outside your home network (Tailscale included), app sign-in isn't offered: use your key or a sign-in link.

---

## GPU acceleration

The `cpu` image works on any Intel or AMD processor, with no graphics card. For more speed on a box with a supported graphics card:

- **NVIDIA:** use `techspecs/ray:cuda` and pass the card through. In compose:

  ```yaml
      deploy:
        resources:
          reservations:
            devices:
              - driver: nvidia
                count: all
                capabilities: [gpu]
  ```

  On Unraid, install the **Nvidia Driver** plugin, then follow its instructions for the container: add `--runtime=nvidia` under **Extra Parameters** and a variable `NVIDIA_VISIBLE_DEVICES` set to `all` (or your card's id).
- **A separate AMD graphics card (Linux host):** use `techspecs/ray:vulkan` and add `devices: ["/dev/dri:/dev/dri", "/dev/kfd:/dev/kfd"]` (`/dev/kfd` lets Sunlight separate voices from the background sound). With `PUID` / `PGID`, Ray adds the devices' groups by itself.
- **Integrated graphics or Intel graphics** (most NAS boxes, Ryzen with Radeon Graphics, Intel N100, Intel Arc): stay on the `cpu` image. Ray Local runs on the processor there.
- **No graphics card, but a PC with one?** See [Use your PC's graphics card](#use-your-pcs-graphics-card-your-devices).
