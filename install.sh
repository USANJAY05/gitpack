#!/usr/bin/env bash
# install.sh - Installer for gitpack (Linux / macOS)
#
# Usage: install.sh [OPTIONS]
#
# Options:
#   --bin-dir <dir>   Install gitpack binary into <dir>  (overrides --prefix/--path)
#   --path <dir>      Alias for --bin-dir
#   --prefix <dir>    Install under <dir>/bin  (default: /usr/local on --system,
#                     $HOME/.local on --user)
#   --system          Install system-wide (default destination: /usr/local/bin)
#   --user            Install for current user only (default: ~/.local/bin)
#   --dry-run         Print what would be done without making any changes
#   -h, --help        Show this help message and exit
#
# When no placement flag is given the installer will prompt interactively.

set -euo pipefail

INSTALLER_VERSION="1.0.0"
GITPACK_BINARY="gitpack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ───────────────────────────────────────────────────────────────────
BIN_DIR=""
PREFIX=""
SYSTEM_INSTALL=false
USER_INSTALL=false
DRY_RUN=false

# ── Colour helpers (graceful degradation) ──────────────────────────────────────
if [[ -t 1 ]] && command -v tput &>/dev/null; then
  BOLD="$(tput bold)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  RED="$(tput setaf 1)"
  RESET="$(tput sgr0)"
else
  BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

info()    { echo "${GREEN}[install]${RESET} $*"; }
warn()    { echo "${YELLOW}[warn]${RESET}   $*" >&2; }
die()     { echo "${RED}[error]${RESET}  $*" >&2; exit 1; }

run() {
  if ${DRY_RUN}; then
    echo "${YELLOW}[dry-run]${RESET} $*"
  else
    "$@"
  fi
}

# ── Usage ───────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}install.sh${RESET} ${INSTALLER_VERSION} — gitpack installer for Linux/macOS

Usage: $(basename "$0") [OPTIONS]

Options:
  --bin-dir <dir>   Install binary into <dir>
  --path <dir>      Alias for --bin-dir
  --prefix <dir>    Install under <dir>/bin
  --system          System-wide install to /usr/local/bin (may require sudo)
  --user            Per-user install to \$HOME/.local/bin
  --dry-run         Show what would happen without making changes
  -h, --help        Show this help and exit

Examples:
  $(basename "$0") --user
  $(basename "$0") --system
  $(basename "$0") --bin-dir /opt/bin
  $(basename "$0") --prefix /opt --dry-run
EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0 ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --system)
      SYSTEM_INSTALL=true; shift ;;
    --user)
      USER_INSTALL=true; shift ;;
    --bin-dir|--path)
      [[ -n "${2:-}" ]] || die "option '$1' requires an argument"
      BIN_DIR="$2"; shift 2 ;;
    --bin-dir=*|--path=*)
      BIN_DIR="${1#*=}"; shift ;;
    --prefix)
      [[ -n "${2:-}" ]] || die "option '$1' requires an argument"
      PREFIX="$2"; shift 2 ;;
    --prefix=*)
      PREFIX="${1#*=}"; shift ;;
    --)
      shift; break ;;
    -*)
      die "unknown option: $1" ;;
    *)
      die "unexpected argument: $1" ;;
  esac
done

# ── Conflict detection ───────────────────────────────────────────────────────────
flags_set=0
${SYSTEM_INSTALL} && ((flags_set++)) || true
${USER_INSTALL}   && ((flags_set++)) || true
[[ -n "$BIN_DIR" ]] && ((flags_set++)) || true
[[ -n "$PREFIX"  ]] && ((flags_set++)) || true

if [[ $flags_set -gt 1 ]]; then
  die "conflicting options: use only one of --system, --user, --bin-dir, --prefix"
fi

# ── Resolve destination directory ────────────────────────────────────────────────
resolve_dest() {
  if [[ -n "$BIN_DIR" ]]; then
    echo "$BIN_DIR"
  elif [[ -n "$PREFIX" ]]; then
    echo "${PREFIX}/bin"
  elif ${SYSTEM_INSTALL}; then
    echo "/usr/local/bin"
  elif ${USER_INSTALL}; then
    echo "${HOME}/.local/bin"
  else
    # Interactive prompt
    echo ""
    echo "Where should gitpack be installed?"
    echo "  1) System-wide  (/usr/local/bin)  [may require sudo]"
    echo "  2) User only    (~/.local/bin)"
    echo "  3) Custom path"
    printf "Choice [1]: "
    read -r choice
    case "${choice:-1}" in
      1) echo "/usr/local/bin" ;;
      2) echo "${HOME}/.local/bin" ;;
      3)
        printf "Enter destination directory: "
        read -r custom_dir
        [[ -n "$custom_dir" ]] || die "no directory provided"
        echo "$custom_dir"
        ;;
      *) die "invalid choice: ${choice}" ;;
    esac
  fi
}

DEST="$(resolve_dest)"

# ── Pre-flight checks ────────────────────────────────────────────────────────────
SOURCE="${SCRIPT_DIR}/${GITPACK_BINARY}"
[[ -f "$SOURCE" ]] || die "binary not found: ${SOURCE}"

info "Source : ${SOURCE}"
info "Dest   : ${DEST}/${GITPACK_BINARY}"
${DRY_RUN} && warn "Dry-run mode — no changes will be made"

# ── Install ──────────────────────────────────────────────────────────────────────
if ! ${DRY_RUN}; then
  if [[ ! -d "$DEST" ]]; then
    info "Creating directory: ${DEST}"
    mkdir -p "$DEST" || die "failed to create ${DEST} (try sudo or choose a different path)"
  fi
fi

run install -m 0755 "$SOURCE" "${DEST}/${GITPACK_BINARY}"
info "Installed ${GITPACK_BINARY} -> ${DEST}/${GITPACK_BINARY}"

# ── PATH advisory ────────────────────────────────────────────────────────────────
if ! ${DRY_RUN}; then
  if [[ ":${PATH}:" != *":${DEST}:"* ]]; then
    warn "${DEST} is not in your PATH."
    warn "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    warn "  export PATH=\"${DEST}:\$PATH\""
  fi
fi

info "Done. Run 'gitpack --help' to get started."
