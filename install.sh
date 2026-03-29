#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/gitpack"

MODE="user"
PREFIX=""
BIN_DIR=""
FORCE=false

show_help() {
  cat <<EOF
gitpack installer (Linux/macOS)

Usage:
  ./install.sh [options]

Options:
  --user            Install to user bin directory (default: ~/.local/bin)
  --system          Install to system bin directory (/usr/local/bin)
  --path <dir>      Install directly to this bin directory (alias of --bin-dir)
  --prefix <dir>    Install under <dir>/bin
  --bin-dir <dir>   Install directly to this bin directory
  --force           Overwrite existing installation
  -h, --help        Show this help
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  local uname_out
  uname_out=$(uname -s 2>/dev/null || echo "unknown")

  case "$uname_out" in
    Linux*) echo "linux" ;;
    Darwin*) echo "mac" ;;
    *) echo "unknown" ;;
  esac
}

is_yes() {
  local answer="${1:-}"
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

get_git_install_cmd() {
  local os
  os=$(detect_os)
  local sudo_prefix=""
  if [[ ${EUID:-$(id -u)} -ne 0 ]] && command_exists sudo; then
    sudo_prefix="sudo "
  fi

  if [[ "$os" == "mac" ]]; then
    if command_exists brew; then
      echo "brew install git"
      return
    fi
    return
  fi

  if [[ "$os" == "linux" ]]; then
    if command_exists apt-get; then
      echo "${sudo_prefix}apt-get update && ${sudo_prefix}apt-get install -y git"
      return
    fi
    if command_exists dnf; then
      echo "${sudo_prefix}dnf install -y git"
      return
    fi
    if command_exists yum; then
      echo "${sudo_prefix}yum install -y git"
      return
    fi
    if command_exists pacman; then
      echo "${sudo_prefix}pacman -Sy --noconfirm git"
      return
    fi
    if command_exists zypper; then
      echo "${sudo_prefix}zypper --non-interactive install git"
      return
    fi
    if command_exists apk; then
      echo "${sudo_prefix}apk add git"
      return
    fi
  fi
}

ensure_git_installed() {
  if command_exists git; then
    return
  fi

  warn "git is not installed, but gitpack requires git for repository-aware modes."
  local install_cmd
  install_cmd=$(get_git_install_cmd || true)

  if [[ -n "$install_cmd" ]]; then
    echo "Install Git with this command:"
    echo "  $install_cmd"

    if [[ -t 0 ]]; then
      local reply
      read -r -p "Run this command now? [Y/n]: " reply
      if is_yes "$reply"; then
        eval "$install_cmd"
      fi
    fi
  fi

  if ! command_exists git; then
    error "git is still not available. Install git, then re-run installer."
  fi
}

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      MODE="user"
      shift
      ;;
    --system)
      MODE="system"
      shift
      ;;
    --prefix)
      [[ $# -lt 2 ]] && error "Missing value for --prefix"
      PREFIX="$2"
      shift 2
      ;;
    --bin-dir)
      [[ $# -lt 2 ]] && error "Missing value for --bin-dir"
      BIN_DIR="$2"
      shift 2
      ;;
    --path)
      [[ $# -lt 2 ]] && error "Missing value for --path"
      BIN_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

[[ -f "$SOURCE_FILE" ]] || error "Cannot find gitpack at: $SOURCE_FILE"

ensure_git_installed

if [[ -n "$BIN_DIR" ]]; then
  :
elif [[ -n "$PREFIX" ]]; then
  BIN_DIR="$PREFIX/bin"
elif [[ "$MODE" == "system" ]]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="$HOME/.local/bin"
fi

TARGET_FILE="$BIN_DIR/gitpack"

mkdir_with_privilege() {
  local dir="$1"
  if mkdir -p "$dir" 2>/dev/null; then
    return
  fi

  command_exists sudo || error "Directory is not writable and sudo is unavailable: $dir"
  sudo mkdir -p "$dir"
}

install_with_privilege() {
  local source="$1"
  local target="$2"

  if install -m 0755 "$source" "$target" 2>/dev/null; then
    return
  fi

  command_exists sudo || error "Target is not writable and sudo is unavailable: $target"
  sudo install -m 0755 "$source" "$target"
}

mkdir_with_privilege "$BIN_DIR"

if [[ -e "$TARGET_FILE" && "$FORCE" != true ]]; then
  error "Target already exists: $TARGET_FILE (use --force to overwrite)"
fi

install_with_privilege "$SOURCE_FILE" "$TARGET_FILE"

log "Installed: $TARGET_FILE"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    log "Path already includes: $BIN_DIR"
    ;;
  *)
    warn "Path does not include $BIN_DIR"
    echo "Add this to your shell profile:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo "Run: gitpack --help"
