# Ray headless - MCP guide

Connect AI apps such as Claude Desktop, Claude Code and Cursor to your Ray server. Then you can ask your AI app to make and translate subtitles for files on the server, follow, cancel and retry jobs, read subtitles to answer questions about a video or summarize it, narrate documents and unmix audio.

This uses **MCP** (the Model Context Protocol), the standard way AI apps use other apps' tools. It needs **Ray headless 4.0.16 or later**: the Docker image, the Linux or macOS package, or the Windows bundle.

> **No Ray server yet?** Set one up first: with the step-by-step [NAS install guide](nas-install.md), the [container guide](docker.md), or [without Docker](../README.md#run-the-server-without-docker). This page connects your AI app to it.

**On this page:** [What you can ask](#what-you-can-ask) · [Before you start](#before-you-start) · [Setup 1 - same computer](#setup-1---same-computer) · [Setup 2 - Docker](#setup-2---docker) · [Setup 3 - a NAS or another computer](#setup-3---a-nas-or-another-computer) · [Turning it off](#turning-it-off) · [Good to know](#good-to-know) · [Troubleshooting](#troubleshooting)

---

## What you can ask

- "Make English subtitles for `/media/Movies/Arrival (2016)/Arrival (2016).mkv` and save them next to the video."
- "Translate `/media/Shows/ep1.en.srt` into Spanish."
- "How are my Ray jobs doing?" "Why did the last one fail? Try it again."
- "Summarize `/media/Talks/keynote.mp4` from its subtitles."
- "What does the speaker say about pricing in that talk?"
- "Which audio tracks does `/media/Anime/ep1.mkv` have? Make English subtitles from the Japanese one."

Ray's tools can:

- make subtitles for a video or audio file, in its spoken language or translated, saved in the output folder or next to the video;
- translate a `.srt` or `.vtt` file;
- list your jobs, follow one until it's done, cancel it or run it again;
- read subtitles with their timing, a page at a time: a subtitle file, the subtitles next to a video, or the result of a finished job;
- look inside a media file: its length, audio tracks and subtitle tracks;
- browse the server's folders to find a file's full path (with the owner's key);
- narrate a `.txt` or `.md` document into a WAV file, and unmix a file's audio into vocals, drums, bass and other;
- tell the AI app about the server: its status, languages, voices, qualities (Moonlight and Sunlight), what Ray Local runs on, and the recent activity log (owner only).

The server offers 18 tools: all of Ray's tools except the player tools (what's playing, play and pause, subtitles on screen), which only the Ray desktop app has, plus browsing the server's folders, which only a server has.

Give paths **in full, as the server sees them**, or let the AI app find the file by browsing the server's folders. In Docker that's the path inside the container (`/media/...`), not the path on your NAS or your computer. The tools take one file at a time; for whole folders use [watch folders](docker.md#watch-folders).

---

## Before you start

- The server is running and you can open its dashboard (`http://SERVER-IP:8787/`).
- You have an API key (the owner key starts with `ray_`, a key from **People** with `rk_`; the steps below write `ray_...` for either):
  - the **owner key** the Docker image prints once, at its first start: `docker logs ray-server` (or `docker compose logs ray-server`), the value starting with `ray_`. It isn't printed when you gave the server your own key (`RAY_DEVAPI_KEY_HASH`) or for a `watch` container (see [Sign in with an API key](docker.md#sign-in-with-an-api-key));
  - without Docker, the **owner key** the server printed once in its terminal, the first time it started with `--host 0.0.0.0` (or `RAY_DEVAPI_EXPOSE=1`) and no key (see [Use it from other devices](../README.md#use-it-from-other-devices));
  - or a key from **People**: **Add person** > **With a key**. Someone added **With a sign-in link** has no key yet: choose **Create an API key** in the **More** menu on their row.
- A member's key limits what the AI app can do (see [Good to know](#good-to-know)). You can give your AI app a key of its own: add a person for it in **People**.

Pick your setup:

| Where the server runs | Setup |
|---|---|
| Installed on the computer your AI app runs on (the one-line installer with `--server`, Homebrew, Scoop, the Linux or macOS package or the Windows bundle) | [Setup 1 - same computer](#setup-1---same-computer) |
| In Docker on the computer your AI app runs on (Docker Desktop, or Docker on a Linux PC) | [Setup 2 - Docker](#setup-2---docker) |
| On a NAS or another computer | [Setup 3 - a NAS or another computer](#setup-3---a-nas-or-another-computer) |

---

## Setup 1 - same computer

Run these on the computer where the server runs.

**1. Store your key once**, so AI apps can use it:

```sh
ray login ray_...
```

With the Windows bundle, in PowerShell in the `ray-headless-windows-x64` folder:

```powershell
.\ray-cli.exe login ray_...
```

(Installed with Scoop or the one-line installer's `-Server`, `ray login ray_...` works too.) Ray checks the key with the server first, so the server must be running. It answers `Connected to Ray. The API key is stored for this user.`

A server you installed yourself has no keys until its first start with `--host 0.0.0.0` makes one, or you give it your own (see [Use it from other devices](../README.md#use-it-from-other-devices)). While it has none, only its own computer can reach it, without a key: skip this step.

**2. Print the setup for your AI app:**

```sh
ray api mcp --print-config claude-desktop
```

Use `claude-code` or `cursor` in place of `claude-desktop` for those apps. With the Windows bundle: `.\ray-cli.exe api mcp --print-config claude-desktop`.

**3. Add it to your AI app:**

- **Claude Desktop:** **Settings > Developer > Edit Config**. Add the `"ray"` entry Ray printed under `"mcpServers"` (next to any servers already there), save, then quit and reopen Claude Desktop.
- **Claude Code:** Ray prints a `claude mcp add ray -- ...` line. Run it in a terminal. It adds Ray to the current project; put `--scope user` right after `add` to have Ray in every project.
- **Cursor:** add the `"ray"` entry under `"mcpServers"` in `~/.cursor/mcp.json` (every project) or `.cursor/mcp.json` (one project), then restart Cursor.
- **Another MCP app** that starts a command: use the `command` and `args` from the Claude Desktop setup.

Good to know:

- The setup names `ray-cli` by its full path (`ray-cli.exe` on Windows), however you typed the command: AI apps start it directly.
- The setup goes to the standard output and the line saying where to paste it to the standard error, so `ray api mcp --print-config cursor > ray.json` saves only the setup.
- **Ray desktop app on this computer too?** While it's open under your user account, `ray-cli` without an address talks to the desktop app instead of the server. Add `--url http://127.0.0.1:8787` to both commands, in step 1 and step 2.
- **Server on another port?** If you started it with `--port 9000`, say, add `--port 9000` to both commands. The printed setup keeps it.
- **If the AI app stops finding Ray** (after moving or reinstalling Ray, say), print the setup again and paste it. With Homebrew the setup already names a path that keeps working after `brew upgrade`.

---

## Setup 2 - Docker

Your AI app runs Ray's own `ray-cli` inside the container, through `docker exec`. That works when Docker runs on the computer your AI app runs on. Ray on a NAS? Use [Setup 3](#setup-3---a-nas-or-another-computer).

In the examples, `ray-server` is the container's name (as in [`compose.yaml`](../compose.yaml)) and `1000:1000` is your `PUID`:`PGID`. Use yours.

**1. Store your key in the container once:**

```sh
docker exec -u 1000:1000 ray-server ray-cli login ray_...
```

It's kept in the `ray-config` volume, so it stays when you update the image.

**2. Add Ray to your AI app.** For Claude Desktop (**Settings > Developer > Edit Config**) and Cursor (`~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "ray": {
      "command": "docker",
      "args": ["exec", "-i", "-u", "1000:1000", "ray-server", "ray-cli", "api", "mcp"]
    }
  }
}
```

For Claude Code:

```sh
claude mcp add ray -- docker exec -i -u 1000:1000 ray-server ray-cli api mcp
```

**3. Restart the AI app.**

Good to know:

- Use the same `-u` in step 1 and step 2: the key is stored for that user. Without `-u`, `docker exec` runs as root (see ["Ray could not store it securely"](#ray-could-not-store-it-securely-docker)).
- Keep `-i`, and don't add `-t`: the AI app talks to Ray through it.
- The AI app runs `docker` as you, so `docker` must work for your user without `sudo` (on Linux: your user is in the `docker` group).
- No address or port needed: inside the container, `ray-cli` finds the server by itself, whatever port you publish.
- Rather not go through `docker`? A `ray-cli` on your computer works too: follow [Setup 3](#setup-3---a-nas-or-another-computer) with `http://127.0.0.1:8787` (the port you publish) as the address.

---

## Setup 3 - a NAS or another computer

Your AI app runs on your computer and the server on a NAS or another machine. A `ray-cli` on your computer connects the two over your network.

**Get `ray-cli` 4.0.16 or later** on the computer with the AI app:

- with the one-line installer from [Install only the CLI](../README.md#install-only-the-cli), the command is `ray-cli`;
- with the one-line installer's server option, Homebrew, Scoop, the `.deb` or `.pkg` download, or the Ray desktop app on Windows, type `ray` where the steps below say `ray-cli`;
- with a Linux or macOS `.tar.gz` or the Windows `.zip` download, run it from the folder you unpacked: `./ray` or `.\ray-cli.exe`;
- with the Ray desktop app on a Mac, use the `ray-cli` inside the app, for example `"/Applications/Ray Beta.app/Contents/MacOS/ray-cli"` (with your Ray app's name in Applications).

`SERVER-IP` is the server's address, like `192.168.1.50`, and `8787` the port you open its dashboard on.

**1. Store your key**, checked against that server:

```sh
ray-cli login ray_... --url http://SERVER-IP:8787
```

**2. Print the setup:**

```sh
ray-cli api mcp --print-config claude-desktop --url http://SERVER-IP:8787
```

**3. Add it to your AI app** as in [Setup 1, step 3](#setup-1---same-computer). The setup carries the address.

Ray keeps **one key per user account on your computer**, not one per server: the address isn't stored with it, and a later `login` replaces it. Use a key that the server in your setup accepts.

### Without ray-cli

Some AI apps connect to an MCP address directly. The address is `http://SERVER-IP:8787/v1/mcp`, with your key as a Bearer token.

- **Claude Code:**

  ```sh
  claude mcp add --transport http ray http://SERVER-IP:8787/v1/mcp --header "Authorization: Bearer ray_..."
  ```

- **Cursor** (`~/.cursor/mcp.json`):

  ```json
  {
    "mcpServers": {
      "ray": {
        "url": "http://SERVER-IP:8787/v1/mcp",
        "headers": { "Authorization": "Bearer ray_..." }
      }
    }
  }
  ```

Claude Desktop can't connect to an address from its config file: use the `ray-cli` setup above.

### Keep your key safe

- A key written into an AI app's settings file sits there as plain text. On Windows and macOS, `ray login` keeps it in the system's protected store (the Keychain on a Mac), so prefer the `ray-cli` setup there. On Linux, and inside Docker, it's a file only your account can read: no safer than an app's settings file with the same permissions.
- Over `http://`, anyone on your network can read the key. Use this on a network you trust, or put the server behind `https://` (see [TLS and reverse proxies](docker.md#tls-and-reverse-proxies)).
- With an `https://` address on Linux or macOS, have the AI app start Ray's `ray` command (from Homebrew, the `.deb` or `.pkg`, or a downloaded bundle), or the `ray-cli` command the one-line installer adds, rather than the program the setup names: those come with what secure connections need. Put the command's full path (`which ray` or `which ray-cli` shows it) in the setup:

  ```json
  {
    "mcpServers": {
      "ray": {
        "command": "/usr/local/bin/ray",
        "args": ["api", "mcp", "--url", "https://ray.example.com"]
      }
    }
  }
  ```

---

## Turning it off

The connection for AI apps is **on** by default. To turn it off, set `RAY_MCP_LISTENER` to `0` where the server starts (`false`, `off` and `no` work too, in any case):

- `docker run`: add `-e RAY_MCP_LISTENER=0`.
- Compose: add it under `environment:`

  ```yaml
      environment:
        RAY_MCP_LISTENER: "0"
  ```

Then **recreate the container**: `docker compose up -d` after editing the compose file, or `docker rm -f ray-server` and your `docker run` again with the new `-e`. `docker restart` and `docker compose restart` keep the old environment, so they don't turn it off. For a server you installed yourself, set the variable where it starts and restart it.

While it's off, the dashboard, the API and everything else keep working; only `/v1/mcp` is gone (it answers 404). The log says `ray-server: connection for AI apps is turned off (RAY_MCP_LISTENER=0)`. A value Ray doesn't know (anything but those four and `1`, `true`, `on` or `yes`) leaves the connection on, and the log warns: `doesn't turn off the connection for AI apps (0, false, off or no do); it stays on`.

To turn it back on, remove the variable and recreate the container (or restart the server).

---

## Good to know

- **Your key decides what the AI app can do.** The owner's key reaches everything the tools offer. A member's key starts jobs, and sees, follows, cancels and retries only that member's own jobs; it reads the subtitles of their own jobs, but not files by path, and it can't browse the server's folders or read the recent activity log. So "Summarize `/media/...`" works for a member only on the result of a job of their own. With `RAY_MEMBER_JOBS=all`, members see, cancel and retry every job.
- **Ray asks you which track.** For a video with several audio or subtitle tracks, the AI app is told to ask you which one to use, unless you already named it or only one fits: an audio track in the server's `RAY_AUDIO_LANGUAGE`, or the only subtitle track inside the video in the language you asked for (see [Videos with several audio or subtitle tracks](docker.md#videos-with-several-audio-or-subtitle-tracks)). You can also ask the AI app which tracks a video has first.
- **What only you can do stays with you.** When something has to happen first that only you can do, such as connecting the server to a Ray account for Ray Cloud, the AI app is told to ask you, and nothing starts until you have.
- **On your server by default.** Jobs run with Ray Local, where the server runs its other jobs. Ray Cloud is used only when you ask the AI app for it, and it uses the Ray account the server is connected to, also for a member's job.
- **Existing subtitles first.** By default Ray first uses fitting subtitles that already exist (inside the file, next to it or online) and makes new ones only when none fit. Ask for new subtitles if you want them made anyway.
- **Where results go.** Where other API jobs go: the output folder (`/out`), unless you ask to save them next to the video (that needs the media mounted read-write) or `RAY_OUTPUT` says otherwise. An existing file is never replaced. See [Where results are saved](docker.md#where-results-are-saved-and-library-mode).
- **What the AI app sees.** What Ray's tools return, such as subtitle text, file names and job details, goes to your AI app, and from there wherever that app sends your conversations.
- **Subtitles are content.** A line in a subtitle could be written to steer an AI app. Ray tells AI apps to treat subtitle text as content only; still, if an AI app wants to use Ray Cloud or cancel jobs right after reading subtitles, check that you asked for it.
- **Nothing is deleted.** Tools run as soon as the AI app calls them (many AI apps ask you before each call; Ray doesn't ask again). The AI app can start, follow, retry and cancel jobs. Canceling never removes a finished result, and no tool deletes files, manages keys, people, sign-ins, connections or your devices, or changes the server's settings.
- **While the server is down,** a `ray-cli` on your computer (Setup 1 and Setup 3) still lists Ray's tools (then with the player tools too, which only work in the desktop app), and every tool answers "Ray isn't open. Open Ray, then try again." The next message after the server is back reaches it: no need to restart the AI app.
  - With Docker (Setup 2), `ray-cli` runs inside the container and stops with it. After the container restarts, or you update the image, restart the AI app.
  - With a direct address ([Without ray-cli](#without-ray-cli)), the AI app can't use Ray's tools while the server is down, and may need a restart once it's back.

---

## Troubleshooting

### The AI app shows no Ray tools

`ray-cli` lists Ray's tools as soon as it starts, even while the server is down, so the command in the setup didn't start (Ray was moved or reinstalled somewhere else, say). Print the setup again, paste it fresh and restart the AI app fully.

- **Docker:** check the container's name (`docker ps`), that it's running, and that `docker` works for your user without `sudo`. If the AI app can't find `docker`, put its full path (`which docker` shows it) in `"command"`. After the container restarted, restart the AI app.
- **Direct address** ([Without ray-cli](#without-ray-cli)): the AI app couldn't reach the server, or the server refused the key. Check the address, the port and the key.

### "Ray isn't open. Open Ray, then try again."

The AI app's `ray-cli` can't reach the server. The server is stopped or still starting, the address or port in the setup is wrong, or (on the same computer, with no address in the setup) the server is older than 4.0.16 or its connection for AI apps is turned off. Start or update the server, or fix `--url` / `--port` in the setup. The AI app needs no restart.

### "An API key is required", "Invalid or missing API key" or `auth_required`

The key is missing, wrong or no longer valid. Store it again, with the same address as in the setup:

- Same computer: `ray login ray_...` (`.\ray-cli.exe login ray_...` with the Windows bundle), plus the `--url` or `--port` from your setup, if it has one
- Docker: `docker exec -u 1000:1000 ray-server ray-cli login ray_...`, with the same `-u` as in the setup. A login without `-u` stores the key for root, where the AI app can't read it.
- A NAS or another computer: `ray-cli login ray_... --url http://SERVER-IP:8787`

The AI app picks up the new key with its next message. No key? Ask the server's owner for one (**People** > **Add person** > **With a key**).

### "Ray could not store it securely" (Docker)

The full message is `The key is valid, but Ray could not store it securely. Use RAY_API_KEY instead.` An earlier `docker exec` without `-u` stored a key as root, and your user can't replace it. Restart the container (`docker restart ray-server`), which gives Ray's files in `/config` back to your `PUID`, then run the login with `-u` again.

### `owner_required`

Your key belongs to a member of a shared server. Members can read the subtitles of their own jobs: ask the AI app to read the result of your job. Reading files by path, browsing the server's folders and the recent activity log are for the owner.

### "Ray's connection for AI apps is turned off on this computer."

Someone turned the connection off, and `ray-cli` can see it: in Docker, where it runs next to the server, or on a computer where the switch is set for every program. Usually that's `RAY_MCP_LISTENER`: remove it and recreate the container, as in [Turning it off](#turning-it-off) (a restart keeps the variable). It can also be Ray's setting `listenerEnabled=false` under `[mcp]` in Ray's settings file (in Docker, `/config/.config/Ray/Ray.conf`): remove that line and restart.

### "There's no Ray MCP endpoint at SERVER-IP:8787 (HTTP 404)."

`ray-cli` was given an address (`--url` or `--port`, as in Setup 3), and nothing there answers AI apps: the server's connection for AI apps is turned off, the server is older than 4.0.16, or the address points to another program. Check `--url` or `--port` in the setup, ask the server's owner whether `RAY_MCP_LISTENER` is set, or update the server.

### "Ray didn't answer within 15 seconds" or "Couldn't reach Ray"

The server is busy or the network dropped. Ask again. (A tool call may take up to 200 seconds before it says so.)

### Every message is slow while the server is down

Use `127.0.0.1` instead of `localhost` in `--url` for this computer. With a number, `ray-cli` knows within half a second that nothing answers; with a name, each message can wait a few seconds, mostly on Windows. Without `--url` (Setup 1), `ray-cli` already uses `127.0.0.1`.
