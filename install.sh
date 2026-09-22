#!/bin/sh
# Ray CLI installer (Linux / macOS) - installs the `ray-cli` client.
#
#   curl -fsSL https://raw.githubusercontent.com/techspecs/ray-headless/main/install.sh | sh
#
# (Installs the newest release, betas included - the script resolves the version via the GitHub API.)
#
# Options (pass after `-s --`, e.g. `... | sh -s -- --dir ~/bin`):
#   --version X    install a specific release tag (default: latest, incl. betas)
#   --dir DIR      install location (default: /usr/local/bin if writable, else ~/.local/bin)
#
# Env equivalents: RAY_VERSION, RAY_INSTALL_DIR
set -eu

REPO="techspecs/ray-headless"
BIN="ray-cli"
VERSION="${RAY_VERSION:-}"
INSTALL_DIR="${RAY_INSTALL_DIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?}"; shift 2 ;;
    --dir)     INSTALL_DIR="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" 2>/dev/null; exit 0 ;;
    *) echo "ray-install: unknown option: $1" >&2; exit 1 ;;
  esac
done

err()  { echo "ray-install: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

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

# ray-cli builds that exist today
case "${OSN}-${ARCHN}" in
  linux-x64|macos-arm64) ASSET="ray-cli-${OSN}-${ARCHN}" ;;
  *) err "no ${BIN} build for ${OSN}-${ARCHN} yet (have: linux-x64, macos-arm64). See https://github.com/${REPO}/releases" ;;
esac

dl()  { if have curl; then curl -fsSL "$1" -o "$2"; elif have wget; then wget -qO "$2" "$1"; else err "need curl or wget"; fi; }
api() { if have curl; then curl -fsSL -H "Accept: application/vnd.github+json" "$1"; else wget -qO- --header="Accept: application/vnd.github+json" "$1"; fi; }

if [ -z "$VERSION" ]; then
  VERSION="$(api "https://api.github.com/repos/${REPO}/releases" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  [ -n "$VERSION" ] || err "could not resolve the latest version; pass --version"
fi

echo "ray-install: ${BIN} ${VERSION} → ${OSN}-${ARCHN}"
BASE="https://github.com/${REPO}/releases/download/${VERSION}"
FILE="${ASSET}-${VERSION}.tar.gz"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
dl "${BASE}/${FILE}" "${tmp}/${FILE}" || err "download failed: ${BASE}/${FILE}"

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

tar -xzf "${tmp}/${FILE}" -C "${tmp}"
src="$(find "${tmp}" -type f -name "${BIN}" 2>/dev/null | head -n1)"
[ -n "$src" ] || err "could not find ${BIN} inside ${FILE}"

if [ -z "$INSTALL_DIR" ]; then
  if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then INSTALL_DIR="/usr/local/bin"; else INSTALL_DIR="${HOME}/.local/bin"; fi
fi
mkdir -p "$INSTALL_DIR"
install -m 0755 "$src" "${INSTALL_DIR}/${BIN}" 2>/dev/null || { cp "$src" "${INSTALL_DIR}/${BIN}"; chmod 0755 "${INSTALL_DIR}/${BIN}"; }
echo "ray-install: installed ${INSTALL_DIR}/${BIN}"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    echo "ray-install: done - run:  ${BIN} --help" ;;
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
    echo "  (new terminals pick it up automatically). Then:  ${BIN} --help"
    ;;
esac
