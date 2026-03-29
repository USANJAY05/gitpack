#!/usr/bin/env bash

# ============================================================
# gitpack test suite
# ============================================================

# Note: intentionally NOT using set -e here so test failures are collected
# rather than aborting the suite. pipefail and nounset are still useful.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/gitpack"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_BOLD="\033[1m"
C_RESET="\033[0m"

pass() { echo -e "${C_GREEN}[PASS]${C_RESET} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "${C_RED}[FAIL]${C_RESET} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo -e "${C_YELLOW}[SKIP]${C_RESET} $1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  [[ "$haystack" == *"$needle"* ]] && pass "$name" || fail "$name (expected: $needle)"
}

assert_not_contains() {
  local haystack="$1" needle="$2" name="$3"
  [[ "$haystack" != *"$needle"* ]] && pass "$name" || fail "$name (unexpected: $needle)"
}

assert_file_exists()  { [[ -f "$1" ]] && pass "$2" || fail "$2 (missing: $1)"; }
assert_file_missing() { [[ ! -f "$1" ]] && pass "$2" || fail "$2 (should not exist: $1)"; }

assert_exit_zero() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name (expected exit 0)"; fi
}

assert_nonzero_exit() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$name (expected non-zero exit, got 0)"; else pass "$name"; fi
}

run_in_temp_dir() {
  local fn="$1" tmp old_pwd
  tmp=$(mktemp -d)
  old_pwd=$(pwd)
  cd "$tmp"
  "$fn"
  cd "$old_pwd"
  rm -rf "$tmp"
}

test_help_and_version() {
  echo ""
  echo -e "${C_BOLD}── Help & Version ───────────────────────────────────────${C_RESET}"

  local out
  out=$("$CLI" --help)
  assert_contains "$out" "gitpack" "help: shows project name"
  assert_contains "$out" "MODES" "help: shows modes section"
  assert_contains "$out" "EXAMPLES" "help: shows examples section"
  assert_contains "$out" "--dry-run" "help: shows --dry-run"
  assert_contains "$out" "--timestamp" "help: shows --timestamp"
  assert_contains "$out" "--overwrite" "help: shows --overwrite"

  local ver
  ver=$("$CLI" --version)
  assert_contains "$ver" "gitpack" "version: includes name"

  local ver2
  ver2=$("$CLI" -V)
  assert_contains "$ver2" "gitpack" "version: -V alias works"
}

test_unknown_arg() {
  echo ""
  echo -e "${C_BOLD}── Error Handling ───────────────────────────────────────${C_RESET}"
  assert_nonzero_exit "unknown flag exits non-zero" "$CLI" --nonexistent-flag
  assert_nonzero_exit "bad mode exits non-zero" "$CLI" --no-git -m badmode --dry-run
  assert_nonzero_exit "bad format exits non-zero" "$CLI" --no-git --format badformat --dry-run
}

test_dry_run_no_git() {
  echo ""
  echo -e "${C_BOLD}── Dry-run (--no-git) ───────────────────────────────────${C_RESET}"

  _inner() {
    echo "hello.txt" > hello.txt
    echo "world.sh"  > world.sh

    local out
    out=$("$CLI" --dry-run --no-git -m everything)
    assert_contains "$out" "hello.txt" "dry-run: lists hello.txt"
    assert_contains "$out" "world.sh"  "dry-run: lists world.sh"
    assert_file_missing "gitpack.zip" "dry-run: does not create archive"
  }
  run_in_temp_dir _inner
}

test_list_mode() {
  echo ""
  echo -e "${C_BOLD}── --list mode ──────────────────────────────────────────${C_RESET}"

  _inner() {
    touch a.txt b.txt c.txt
    local out
    out=$("$CLI" --list --no-git -m everything)
    assert_contains "$out" "3 file(s) selected" "list: shows file count"
  }
  run_in_temp_dir _inner
}

test_zip_creation_no_git() {
  echo ""
  echo -e "${C_BOLD}── zip creation (--no-git) ──────────────────────────────${C_RESET}"

  if ! command -v zip >/dev/null 2>&1; then
    skip "zip not installed — skipping zip tests"
    return
  fi

  _inner() {
    echo "content" > file1.txt
    mkdir -p src
    echo "src" > src/main.sh

    "$CLI" --no-git -m everything -o out.zip
    assert_file_exists "out.zip" "zip: creates out.zip"

    local listing
    listing=$(unzip -l out.zip 2>/dev/null)
    assert_contains "$listing" "file1.txt" "zip: contains file1.txt"
    assert_contains "$listing" "main.sh"   "zip: contains src/main.sh"
  }
  run_in_temp_dir _inner
}

test_targz_creation_no_git() {
  echo ""
  echo -e "${C_BOLD}── tar.gz creation (--no-git) ───────────────────────────${C_RESET}"

  _inner() {
    echo "content" > file1.txt
    mkdir -p lib
    echo "lib" > lib/utils.sh

    "$CLI" --no-git -m everything --format tar.gz -o out.tar.gz
    assert_file_exists "out.tar.gz" "tar.gz: creates archive"

    local listing
    listing=$(tar -tzf out.tar.gz 2>/dev/null)
    assert_contains "$listing" "file1.txt" "tar.gz: contains file1.txt"
    assert_contains "$listing" "utils.sh"  "tar.gz: contains lib/utils.sh"
  }
  run_in_temp_dir _inner
}

test_include_exclude() {
  echo ""
  echo -e "${C_BOLD}── Include / Exclude filters ────────────────────────────${C_RESET}"

  _inner() {
    echo "a" > app.js
    echo "b" > app.py
    echo "c" > node_modules_dummy.js

    local out
    out=$("$CLI" --dry-run --no-git -m everything --include '\.js$')
    assert_contains     "$out" "app.js"             "include: selects .js files"
    assert_not_contains "$out" "app.py"             "include: omits .py files"

    out=$("$CLI" --dry-run --no-git -m everything --exclude '\.py$')
    assert_not_contains "$out" "app.py"             "exclude: omits .py files"
    assert_contains     "$out" "app.js"             "exclude: keeps .js files"

    out=$("$CLI" --dry-run --no-git -m everything --include '\.js$' --exclude 'node_modules')
    assert_contains     "$out" "app.js"             "include+exclude: keeps app.js"
    assert_not_contains "$out" "node_modules_dummy" "include+exclude: drops node_modules"
  }
  run_in_temp_dir _inner
}

test_max_size() {
  echo ""
  echo -e "${C_BOLD}── --max-size filter ────────────────────────────────────${C_RESET}"

  _inner() {
    printf '%0.s.' {1..100} > small.txt
    dd if=/dev/zero bs=2000 count=1 of=big.txt 2>/dev/null

    local out
    out=$("$CLI" --dry-run --no-git -m everything --max-size 500)
    assert_contains     "$out" "small.txt" "max-size: keeps small file"
    assert_not_contains "$out" "big.txt"   "max-size: drops big file"
  }
  run_in_temp_dir _inner
}

test_gitpackignore() {
  echo ""
  echo -e "${C_BOLD}── .gitpackignore ───────────────────────────────────────${C_RESET}"

  _inner() {
    touch keep.txt drop.log secret.env
    printf '\.log$\n\.env$\n' > .gitpackignore

    local out
    out=$("$CLI" --dry-run --no-git -m everything)
    assert_contains     "$out" "keep.txt"   "gitpackignore: keeps non-ignored"
    assert_not_contains "$out" "drop.log"   "gitpackignore: drops .log"
    assert_not_contains "$out" "secret.env" "gitpackignore: drops .env"
  }
  run_in_temp_dir _inner
}

test_timestamp_flag() {
  echo ""
  echo -e "${C_BOLD}── --timestamp flag ─────────────────────────────────────${C_RESET}"

  if ! command -v zip >/dev/null 2>&1; then
    skip "--timestamp: zip not installed"
    return
  fi

  _inner() {
    touch file.txt
    local out
    out=$("$CLI" --no-git -m everything --timestamp 2>&1)
    assert_contains "$out" "gitpack-" "timestamp: output name contains gitpack-"

    local archive
    archive=$(find . -name "gitpack-*.zip" | head -1)
    [[ -n "$archive" ]] && pass "timestamp: archive file exists" || fail "timestamp: no timestamped archive found"
  }
  run_in_temp_dir _inner
}

test_overwrite_flag() {
  echo ""
  echo -e "${C_BOLD}── --overwrite flag ─────────────────────────────────────${C_RESET}"

  if ! command -v zip >/dev/null 2>&1; then
    skip "--overwrite: zip not installed"
    return
  fi

  _inner() {
    touch file.txt
    echo "old" > existing.zip
    if "$CLI" --no-git -m everything -o existing.zip 2>/dev/null; then
      fail "overwrite: should error without --overwrite in non-interactive"
    else
      pass "overwrite: errors without flag"
    fi
    "$CLI" --no-git -m everything -o existing.zip --overwrite >/dev/null 2>&1
    assert_file_exists "existing.zip" "overwrite: succeeds with --overwrite"
  }
  run_in_temp_dir _inner
}

test_no_empty() {
  echo ""
  echo -e "${C_BOLD}── --no-empty ───────────────────────────────────────────${C_RESET}"

  _inner() {
    assert_nonzero_exit "no-empty: exits non-zero when no files" \
      "$CLI" --no-git -m everything --no-empty --dry-run
  }
  run_in_temp_dir _inner
}

test_base_dir() {
  echo ""
  echo -e "${C_BOLD}── --base-dir ───────────────────────────────────────────${C_RESET}"

  local tmp
  tmp=$(mktemp -d)
  echo "hello" > "$tmp/hello.txt"

  local out
  out=$("$CLI" --dry-run --no-git -m everything --base-dir "$tmp")
  assert_contains "$out" "hello.txt" "base-dir: finds file in specified dir"

  rm -rf "$tmp"
}

test_select_mode() {
  echo ""
  echo -e "${C_BOLD}── .gitpackselect ───────────────────────────────────────${C_RESET}"

  _inner() {
    touch a.txt b.txt c.txt
    printf 'a.txt\n' > .gitpackselect

    local out
    out=$("$CLI" --dry-run --no-git -m everything --use-select)
    assert_contains     "$out" "a.txt" "selectmode: includes a.txt"
    assert_not_contains "$out" "b.txt" "selectmode: excludes b.txt"
    assert_not_contains "$out" "c.txt" "selectmode: excludes c.txt"
  }
  run_in_temp_dir _inner
}

test_select_and_ignore_conflict() {
  echo ""
  echo -e "${C_BOLD}── select + ignore conflict ─────────────────────────────${C_RESET}"

  _inner() {
    touch file.txt
    echo "file.txt" > .gitpackselect
    echo "skip"     > .gitpackignore
    assert_nonzero_exit "conflict: errors when both files present with --use-select" \
      "$CLI" --no-git -m everything --use-select --dry-run
  }
  run_in_temp_dir _inner
}

# ─────────────────────────────────────────────────────────────
echo -e "${C_BOLD}gitpack test suite${C_RESET}"
echo "CLI: $CLI"
echo ""

test_help_and_version
test_unknown_arg
test_dry_run_no_git
test_list_mode
test_zip_creation_no_git
test_targz_creation_no_git
test_include_exclude
test_max_size
test_gitpackignore
test_timestamp_flag
test_overwrite_flag
test_no_empty
test_base_dir
test_select_mode
test_select_and_ignore_conflict

echo ""
echo -e "────────────────────────────────────────────────────────"
echo -e "${C_GREEN}PASS: $PASS_COUNT${C_RESET}  ${C_RED}FAIL: $FAIL_COUNT${C_RESET}  ${C_YELLOW}SKIP: $SKIP_COUNT${C_RESET}"

[[ $FAIL_COUNT -eq 0 ]]
