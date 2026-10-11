#!/bin/sh
# Ray installer (Linux / macOS) - installs the `ray-cli` client, or with --server the whole
# Ray Headless server: the `ray` command (`ray serve` starts it) and `ray-cli`.
#
#   curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh -s -- --server
#
# (Installs the newest release, betas included - the script resolves the version via the GitHub API.)
#
# Options (pass after `-s --`, e.g. `... | sh -s -- --dir ~/bin`):
#   --server       install the server too (Linux x64, macOS on Apple silicon); its download is
#                  several hundred MB
#   --version X    install a specific release tag (default: latest, incl. betas)
#   --dir DIR      where the commands go (default: /usr/local/bin if writable,
#                  else ~/.local/bin)
#   --lib-dir DIR  where the program's files go (default: the lib folder next to a system
#                  --dir, like /usr/local/lib/ray-cli, else ~/.local/lib/ray-cli; with
#                  --server ray-headless in place of ray-cli)
#
# Env equivalents: RAY_INSTALL_SERVER=1, RAY_VERSION, RAY_INSTALL_DIR, RAY_LIB_DIR
set -eu

REPO="techspecs/ray-headless"
BIN="ray-cli"
SERVER="${RAY_INSTALL_SERVER:-}"
TAG="${RAY_VERSION:-}"        # the release (--version)
INSTALL_DIR="${RAY_INSTALL_DIR:-}"
LIB_DIR="${RAY_LIB_DIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --server)  SERVER=1; shift ;;
    --version) TAG="${2:?}"; shift 2 ;;
    --dir)     INSTALL_DIR="${2:?}"; shift 2 ;;
    --lib-dir) LIB_DIR="${2:?}"; shift 2 ;;
    -h|--help)
      # (piped into sh there is no file to read the notes from)
      awk 'NR == 1 { next } /^#/ { print; next } { exit }' "$0" 2>/dev/null \
        || echo "ray-install options: --server  --version X  --dir DIR  --lib-dir DIR (see the top of install.sh)"
      exit 0 ;;
    *) echo "ray-install: unknown option: $1" >&2; exit 1 ;;
  esac
done
case "$SERVER" in 1|true|yes|on) SERVER=1 ;; *) SERVER="" ;; esac

err()  { echo "ray-install: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# The client is the small `ray-cli` bundle; the server is the full `ray-headless` bundle
# (ray-server, ray-cli and the `ray` launcher).
if [ -n "$SERVER" ]; then NAME="ray-headless"; WHAT="Ray Headless server"; else NAME="$BIN"; WHAT="$BIN"; fi

os="$(uname -s)"; arch="$(uname -m)"
case "$os" in
  Linux)  OSN="linux" ;;
  Darwin) OSN="macos" ;;
  *) err "unsupported OS '$os' - on Windows use install.ps1" ;;
esac
case "$arch" in
  x86_64|amd64)  ARCHN="x64" ;;
  arm64|aarch64) ARCHN="arm64" ;;
  *) err "unsupported architecture '$arch'" ;;
esac

# builds that exist today (the same for the client and the server)
case "${OSN}-${ARCHN}" in
  linux-x64|macos-arm64) ASSET="${NAME}-${OSN}-${ARCHN}" ;;
  *) err "no ${WHAT} build for ${OSN}-${ARCHN} yet (have: linux-x64, macos-arm64). See https://github.com/${REPO}/releases" ;;
esac

if [ -z "$INSTALL_DIR" ]; then
  if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then INSTALL_DIR="/usr/local/bin"; else INSTALL_DIR="${HOME}/.local/bin"; fi
fi
if [ -z "$LIB_DIR" ]; then
  # The lib folder beside a system bin folder (/usr/local/bin -> /usr/local/lib/ray-cli), so a
  # command installed for everyone never points into the home of whoever installed it.
  case "${INSTALL_DIR%/}" in
    "${HOME:-/dev/null}"/*) LIB_DIR="${HOME}/.local/lib/${NAME}" ;;
    ?*/bin)      LIB_DIR="${INSTALL_DIR%/}"; LIB_DIR="${LIB_DIR%/bin}/lib/${NAME}" ;;
    *)           LIB_DIR="${HOME}/.local/lib/${NAME}" ;;
  esac
fi
case "$LIB_DIR" in /|"") err "refusing to install into '${LIB_DIR}'" ;; esac
# The files' folder is replaced as a whole, so it must be new, empty or an earlier install.
if [ -e "$LIB_DIR" ] && ! { [ -f "${LIB_DIR}/ray" ] && [ -e "${LIB_DIR}/bin/${BIN}" ]; } \
   && [ -n "$(ls -A "$LIB_DIR" 2>/dev/null || echo x)" ]; then
  err "${LIB_DIR} holds other files; choose a new folder with --lib-dir"
fi
# `ray` is a common name: never replace another program's. (Ray's own launcher, or a link to it,
# is replaced; so is a link that leads nowhere.)
if [ -n "$SERVER" ] && [ -e "${INSTALL_DIR}/ray" ] \
   && ! grep -q 'Ray headless CLI launcher' "${INSTALL_DIR}/ray" 2>/dev/null; then
  err "${INSTALL_DIR}/ray is another program; choose another folder for the commands with --dir"
fi

dl()  { if have curl; then curl -fsSL "$1" -o "$2"; elif have wget; then wget -qO "$2" "$1"; else err "need curl or wget"; fi; }
api() { if have curl; then curl -fsSL -H "Accept: application/vnd.github+json" "$1"; else wget -qO- --header="Accept: application/vnd.github+json" "$1"; fi; }
# The same with a progress meter (amount, speed, time left), for the server's big download.
dlp() {
  if have curl; then curl -fL "$1" -o "$2"
  elif have wget; then
    if wget --help 2>&1 | grep -q -- '--show-progress'; then wget -q --show-progress -O "$2" "$1"; else wget -O "$2" "$1"; fi
  else err "need curl or wget"; fi
}

if [ -z "$TAG" ]; then
  # (the whole answer is read, so curl never says it could not write)
  TAG="$(api "https://api.github.com/repos/${REPO}/releases?per_page=1" | tr ',' '\n' \
    | awk -F'"' '/"tag_name"/ && v == "" { v = $4 } END { print v }')"
  [ -n "$TAG" ] || err "could not resolve the latest version; pass --version"
fi

if [ -n "$SERVER" ]; then
  echo "ray-install: ${WHAT} ${TAG} → ${OSN}-${ARCHN} (a download of several hundred MB)"
else
  echo "ray-install: ${WHAT} ${TAG} → ${OSN}-${ARCHN}"
fi
BASE="https://github.com/${REPO}/releases/download/${TAG}"
FILE="${ASSET}-${TAG}.tar.gz"

mkdir -p "$INSTALL_DIR" "$(dirname "$LIB_DIR")"
LIB_DIR="$(cd "$(dirname "$LIB_DIR")" && pwd)/$(basename "$LIB_DIR")"
if [ -n "$SERVER" ]; then
  # The server unpacks to more than a GB: it is unpacked next to where it goes (not in a small
  # /tmp) and moved into place without a second copy.
  tmp="$(mktemp -d "$(dirname "$LIB_DIR")/.${NAME}-install.XXXXXX")"
else
  tmp="$(mktemp -d)"
fi
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT HUP TERM
if [ -n "$SERVER" ]; then
  dlp "${BASE}/${FILE}" "${tmp}/${FILE}" || err "download failed: ${BASE}/${FILE}"
else
  dl "${BASE}/${FILE}" "${tmp}/${FILE}" || err "download failed: ${BASE}/${FILE}"
fi

# verify against SHA256SUMS when possible
if dl "${BASE}/SHA256SUMS" "${tmp}/SHA256SUMS" 2>/dev/null; then
  want="$(grep " ${FILE}\$" "${tmp}/SHA256SUMS" 2>/dev/null | awk '{print $1}')"
  if [ -n "${want:-}" ]; then
    if   have sha256sum; then got="$(sha256sum "${tmp}/${FILE}" | awk '{print $1}')"
    elif have shasum;    then got="$(shasum -a 256 "${tmp}/${FILE}" | awk '{print $1}')"
    else got=""; fi
    [ -n "$got" ] && [ "$got" != "$want" ] && err "checksum mismatch for ${FILE}"
    [ -n "$got" ] && echo "ray-install: checksum ok"
  fi
fi

mkdir -p "${tmp}/x"
if [ -n "$SERVER" ]; then
  echo "ray-install: unpacking"
  # (files owned by whoever installs, never by the account that built the bundle)
  tar --no-same-owner -xzf "${tmp}/${FILE}" -C "${tmp}/x"
  rm -f "${tmp}/${FILE}"
  # The server bundle: bin/ray-server and bin/ray-cli with their libraries (lib/), tools and
  # certificates, and the `ray` launcher at its top that sets them up.
  exe="$(find "${tmp}/x" -maxdepth 3 -type f -path "*/bin/ray-server" 2>/dev/null | head -n1)"
  [ -n "$exe" ] || err "could not find bin/ray-server inside ${FILE}"
else
  tar -xzf "${tmp}/${FILE}" -C "${tmp}/x"
  # The CLI is a small bundle: bin/ray-cli needs the libraries and certificates beside it (lib/,
  # share/) and the `ray` launcher that sets them up. It is installed whole, never the program alone.
  exe="$(find "${tmp}/x" -type f -path "*/bin/${BIN}" 2>/dev/null | head -n1)"
  [ -n "$exe" ] || err "could not find bin/${BIN} inside ${FILE}"
fi
bundle="$(cd "$(dirname "$exe")/.." && pwd)"
[ -x "${bundle}/ray" ] || err "the ${FILE} bundle has no launcher; see https://github.com/${REPO}/releases"
[ -x "${bundle}/bin/${BIN}" ] || err "the ${FILE} bundle has no ${BIN}; see https://github.com/${REPO}/releases"

# Replace an earlier copy in one step: the new files go next to it first.
rm -rf "${LIB_DIR}.new"
if [ -n "$SERVER" ]; then mv "$bundle" "${LIB_DIR}.new"; else cp -R "$bundle" "${LIB_DIR}.new"; fi
find "${LIB_DIR}.new" -name '._*' -type f -exec rm -f {} + 2>/dev/null || true
rm -rf "${LIB_DIR}.old"
[ -e "$LIB_DIR" ] && mv "$LIB_DIR" "${LIB_DIR}.old"
mv "${LIB_DIR}.new" "$LIB_DIR"
rm -rf "${LIB_DIR}.old"

# The `ray-cli` command: runs the bundle's launcher (which sets up its libraries, plugins and
# certificates) with the CLI. It replaces an earlier install's bare program too.
# (the folder in single quotes, so no character in its name can mean anything to the shell)
quoted="'$(printf '%s' "$LIB_DIR" | sed "s/'/'\\\\''/g")'"
rm -f "${INSTALL_DIR}/${BIN}"
printf '#!/bin/sh\n# Ray CLI - installed by install.sh from %s; its files are in %s\nexec %s/ray api "$@"\n' \
  "$TAG" "$LIB_DIR" "$quoted" > "${INSTALL_DIR}/${BIN}"
chmod 0755 "${INSTALL_DIR}/${BIN}"
if [ -n "$SERVER" ]; then
  # The `ray` command: a link to the bundle's launcher, which follows it back to its files.
  rm -f "${INSTALL_DIR}/ray"
  ln -s "${LIB_DIR}/ray" "${INSTALL_DIR}/ray"
fi

# It must start here (its libraries load), or nothing is said to be installed. The check keeps
# its folders in the download folder: under `sudo` it must not leave root's files in your home.
mkdir -p "${tmp}/home"
starts() {
  code=0
  out="$(env HOME="${tmp}/home" XDG_DATA_HOME="${tmp}/home/share" XDG_CONFIG_HOME="${tmp}/home/config" \
         XDG_CACHE_HOME="${tmp}/home/cache" RAY_MODEL_ROOT="${tmp}/home/models" \
         RAY_LOCAL_STORAGE_ROOT="${tmp}/home/data" RAY_DEVAPI_RESULTS_DIR="${tmp}/home/out" \
         "$@" 2>&1)" || code=$?
  ! { [ "$code" -ge 126 ] || printf '%s' "$out" | grep -qiE 'error while loading shared|library not loaded|cannot open shared object|bundle looks incomplete'; }
}
if ! starts "${INSTALL_DIR}/${BIN}" --help; then
  printf '%s\n' "$out" | head -n 5 >&2
  err "${INSTALL_DIR}/${BIN} was installed but does not start"
fi

# The server bundle carries its libraries, except a few every desktop has and a bare server
# may not (sound, graphics). The ones this system lacks, by file name:
missing_libs() {
  [ "$OSN" = linux ] && have ldd || return 0
  find "${LIB_DIR}/bin" -type f -perm -u+x 2>/dev/null | while IFS= read -r f; do
    LD_LIBRARY_PATH="${LIB_DIR}/lib" ldd "$f" 2>/dev/null | awk '/not found/ { print $1 }'
  done | sort -u | while IFS= read -r so; do
    [ -n "$(find "$LIB_DIR" -name "$so" 2>/dev/null | head -n1)" ] || echo "$so"
  done
}
# The command that installs them, with the system's own package tool.
libs_command() {
  sudo=""; [ "$(id -u)" -eq 0 ] || sudo="sudo "
  if have apt-get; then
    pkgs=""
    for so in "$@"; do
      case "$so" in
        libasound.so.2)
          if apt-cache show libasound2t64 >/dev/null 2>&1; then p=libasound2t64
          elif apt-cache show libasound2 >/dev/null 2>&1; then p=libasound2
          else
            # no package lists yet: from Ubuntu 24.04 and Debian 13 on it has its new name
            # shellcheck source=/dev/null
            case "$( . /etc/os-release 2>/dev/null; echo "${ID:-}:${VERSION_ID:-}")" in
              ubuntu:2[4-9]*|ubuntu:[3-9][0-9]*|debian:1[3-9]*) p=libasound2t64 ;;
              *) p=libasound2 ;;
            esac
          fi ;;
        libEGL.so.1) p=libegl1 ;;
        libGL.so.1) p=libgl1 ;;
        libGLX.so.0) p=libglx0 ;;
        libOpenGL.so.0) p=libopengl0 ;;
        libGLdispatch.so.0) p=libglvnd0 ;;
        libdbus-1.so.3) p=libdbus-1-3 ;;
        libpulse.so.0|libpulse-simple.so.0) p=libpulse0 ;;
        libvulkan.so.1) p=libvulkan1 ;;
        libdrm.so.2) p=libdrm2 ;;
        libgbm.so.1) p=libgbm1 ;;
        libgomp.so.1) p=libgomp1 ;;
        libfontconfig.so.1) p=libfontconfig1 ;;
        libfreetype.so.6) p=libfreetype6 ;;
        *) continue ;;
      esac
      case " $pkgs " in *" $p "*) ;; *) pkgs="${pkgs:+$pkgs }$p" ;; esac
    done
    [ -n "$pkgs" ] || return 0
    if ls /var/lib/apt/lists/*_Packages >/dev/null 2>&1; then
      echo "${sudo}apt-get install -y ${pkgs}"
    else
      echo "${sudo}apt-get update && ${sudo}apt-get install -y ${pkgs}"
    fi
    return 0
  fi
  # rpm systems install a library by its own name
  for tool in dnf yum zypper; do
    if have "$tool"; then
      printf '%s%s install -y' "$sudo" "$tool"
      for so in "$@"; do printf " '%s()(64bit)'" "$so"; done
      echo
      return 0
    fi
  done
}

server_ok=1
missing=""
if [ -n "$SERVER" ]; then
  missing="$(missing_libs | tr '\n' ' ')"; missing="${missing% }"
  starts "${INSTALL_DIR}/ray" version || server_ok=""
  if [ -z "$server_ok" ] && [ -z "$missing" ]; then
    printf '%s\n' "$out" | head -n 5 >&2
    err "the server (${INSTALL_DIR}/ray) was installed but does not start"
  fi
  echo "ray-install: installed ${INSTALL_DIR}/ray and ${INSTALL_DIR}/${BIN} (files in ${LIB_DIR})"
  if [ -n "$missing" ]; then
    echo ""
    echo "ray-install: Ray Headless also needs a few system libraries this computer doesn't have yet:"
    echo "      ${missing}"
    # shellcheck disable=SC2086
    fix="$(libs_command $missing)"
    if [ -n "$fix" ]; then
      echo "  Install them with:"
      echo "      ${fix}"
    else
      echo "  Install them with your system's package manager."
    fi
    if [ -n "$server_ok" ]; then echo "  (The server starts without them, but some jobs need them.)"; fi
    echo ""
  fi
  next="ray serve   (then open http://127.0.0.1:8787/ on this computer, or the port its \"listening on\" line shows)"
else
  echo "ray-install: installed ${INSTALL_DIR}/${BIN} (files in ${LIB_DIR})"
  next="${BIN} --help"
fi
if [ -n "$server_ok" ]; then done_line="done - run:"; else done_line="once those are installed, run:"; fi

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    echo "ray-install: ${done_line}  ${next}"
    if [ -n "$SERVER" ]; then
      found="$(command -v ray 2>/dev/null || true)"
      # (by file, not name: on some systems /usr/local/sbin is /usr/local/bin. Every sh in use
      # has -ef, though POSIX leaves it out.)
      # shellcheck disable=SC3013
      if [ -n "$found" ] && ! [ "$found" -ef "${INSTALL_DIR}/ray" ]; then
        echo "ray-install: note - \`ray\` here starts ${found}, which comes first on your PATH; use ${INSTALL_DIR}/ray"
      fi
    fi
    ;;
  *)
    case "${SHELL:-}" in
      */zsh)  rc="${HOME}/.zshrc" ;;
      */bash) rc="${HOME}/.bashrc" ;;
      *)      rc="${HOME}/.profile" ;;
    esac
    line="export PATH=\"${INSTALL_DIR}:\$PATH\""
    if ! grep -qsF "$line" "$rc" 2>/dev/null; then
      printf '\n# Ray CLI\n%s\n' "$line" >> "$rc"
      echo "ray-install: added ${INSTALL_DIR} to PATH in ${rc}"
    fi
    echo ""
    echo "  ${INSTALL_DIR} isn't on PATH in THIS shell yet. Activate it now:"
    echo "      export PATH=\"${INSTALL_DIR}:\$PATH\""
    if [ -n "$server_ok" ]; then
      echo "  (new terminals pick it up automatically). Then:  ${next}"
    else
      echo "  (new terminals pick it up automatically). Once those libraries are installed:  ${next}"
    fi
    ;;
esac
# The server can't start until those libraries are there.
[ -n "$server_ok" ] || exit 1
