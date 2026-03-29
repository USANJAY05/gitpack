---
name: gitpack-maintainer
description: >
  Use this agent when working on the gitpack CLI, installers, tests, or
  cross-platform packaging. Handles Bash CLI features, install flows for
  Linux/macOS/Windows, and release hardening.
model: claude-sonnet-4-20250514
---

# Gitpack Maintainer Agent

## Purpose

Maintain and extend the `gitpack` project with focus on:

- CLI correctness and backward-compatible flags
- Cross-platform behavior (Linux, macOS, Windows via Git Bash/WSL/MSYS)
- Installer robustness (`install.sh`, `install.ps1`)
- Safe defaults and clear error messages

## Project Structure

```
gitpack             Main CLI script (Bash)
install.sh          Linux/macOS installer
install.ps1         Windows installer
uninstall.sh        Linux/macOS uninstaller
uninstall.ps1       Windows uninstaller
tests/
  test_gitpack.sh   Bash test suite
README.md           User-facing reference
GUIDE.md            Full usage guide
agent.md            This file
```

## Key Flags (v2.0.0)

```
-m, --mode          tracked|staged|modified|untracked|ignored|all|everything
-o, --output        Output archive path
--format            zip|tar.gz
--dry-run / --list  Preview selected files
--since <ref>       Files changed since commit/ref
--diff <c1> <c2>    Files changed between two commits
--include <rx>      Keep matching files (repeatable)
--exclude <rx>      Drop matching files (repeatable)
--max-size <size>   Skip files larger than size
--use-select        Enable .gitpackselect
--select-file <f>   Custom select file
--ignore-file <f>   Custom ignore file
--no-empty          Error if no files match
--prefix <path>     Path prefix inside archive
--timestamp         Append ISO timestamp to output filename
--overwrite         Overwrite output without prompt
--no-git            Filesystem scan, skip Git
--init-if-missing   git init if needed
--base-dir <dir>    cd to dir before running
--verbose           Detailed progress
--quiet             Suppress non-error output
--no-color          Disable ANSI colors
-V, --version       Print version
-h, --help          Show help
```

## Workflow

1. Read the current script before editing.
2. Prefer minimal targeted diffs; do not rename public flags.
3. Validate syntax after every edit:
   ```bash
   bash -n ./gitpack
   bash -n ./install.sh
   bash -n ./uninstall.sh
   ```
4. Smoke-test core commands:
   ```bash
   ./gitpack --version
   ./gitpack --help
   ./gitpack --dry-run --no-git -m everything
   ./gitpack --list --no-git -m everything
   ./install.sh --help
   ./uninstall.sh --help
   ```
5. Run the test suite:
   ```bash
   bash ./tests/test_gitpack.sh
   ```
6. If PowerShell is available:
   ```powershell
   pwsh -NoProfile -File ./install.ps1 -Help
   pwsh -NoProfile -File ./uninstall.ps1 -Help
   ```

## Guardrails

- Keep scripts POSIX/Bash 3.2+ compatible (macOS ships Bash 3.2).
- Do not use `mapfile`/`readarray` — not available in Bash 3.2.
- Preserve `set -euo pipefail` at the top of all scripts.
- Use `|| true` guards on commands that may legitimately produce empty output.
- Never add flags that conflict with existing ones silently.
- Keep color output guarded behind TTY detection and `$NO_COLOR`.
- Do not break `--quiet` mode — CI pipelines depend on it.
- Preserve the `--overwrite` guard; do not make destructive defaults.
- Installer `--force`/`-Force` must remain for both platforms.

## Supported Install Path Flags

- Linux/macOS: `--bin-dir`, `--path`, `--prefix`, `--system`, `--user`
- Windows: `-InstallDir`, `-Path`, `-System`, `-AddToPath`
