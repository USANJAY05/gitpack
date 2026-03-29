#!/usr/bin/env bash

set -euo pipefail

TARGET_NAME="gitpack"
REMOVE_ALL=false
YES=false

show_help() {
  cat <<EOF
gitpack uninstaller (Linux/macOS)

Usage:
  ./uninstall.sh [options]

Options:
  --all        Remove all discovered gitpack executables
  -y, --yes    Do not prompt for confirmation
  -h, --help   Show this help
EOF
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

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_yes() {
  local answer="${1:-}"
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

remove_file_with_privilege() {
  local target="$1"

  if rm -f "$target" 2>/dev/null; then
    return
  fi

  if command_exists sudo; then
    sudo rm -f "$target"
    return
  fi

  error "Cannot remove $target (permission denied and sudo unavailable)"
}

collect_candidates() {
  local found=""

  # Check default install locations even if they are not in PATH.
  local default_user="$HOME/.local/bin/$TARGET_NAME"
  local default_system="/usr/local/bin/$TARGET_NAME"
  [[ -f "$default_user" ]] && found+="$default_user"$'\n'
  [[ -f "$default_system" ]] && found+="$default_system"$'\n'

  if command_exists "$TARGET_NAME"; then
    found+="$(command -v "$TARGET_NAME")"$'\n'
  fi

  local path_dir
  IFS=':' read -r -a path_dirs <<< "${PATH:-}"
  for path_dir in "${path_dirs[@]}"; do
    [[ -z "$path_dir" ]] && continue
    if [[ -f "$path_dir/$TARGET_NAME" ]]; then
      found+="$path_dir/$TARGET_NAME"$'\n'
    fi
  done

  printf "%s" "$found" | awk 'NF' | sort -u
}

confirm_or_exit() {
  local message="$1"
  if [[ "$YES" == true || ! -t 0 ]]; then
    return
  fi

  local reply
  read -r -p "$message [y/N]: " reply
  if ! is_yes "$reply"; then
    error "Aborted"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      REMOVE_ALL=true
      shift
      ;;
    -y|--yes)
      YES=true
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

candidates=()
while IFS= read -r line; do
  [[ -n "$line" ]] && candidates+=("$line")
done < <(collect_candidates)

if [[ ${#candidates[@]} -eq 0 ]]; then
  warn "No installed gitpack executable found"
  exit 0
fi

if [[ "$REMOVE_ALL" == false ]]; then
  candidates=("${candidates[0]}")
fi

log "Found target(s):"
for c in "${candidates[@]}"; do
  echo "  $c"
done

if [[ ${#candidates[@]} -eq 1 ]]; then
  confirm_or_exit "Remove this gitpack executable?"
else
  confirm_or_exit "Remove all discovered gitpack executables?"
fi

for target in "${candidates[@]}"; do
  remove_file_with_privilege "$target"
  log "Removed: $target"
done

log "Uninstall complete"
