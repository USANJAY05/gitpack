# gitpack

> Git-aware archive tool for Linux, macOS, and Windows.

`gitpack` creates `.zip` or `.tar.gz` archives from files selected by Git status, commit range, or filesystem scan — with regex filters, size limits, and ignore/select lists.

---

## Install

### Linux / macOS

```bash
./install.sh
```

Common options:

```bash
./install.sh --system              # install to /usr/local/bin
./install.sh --path /opt/tools/bin # install to a custom bin dir
./install.sh --force               # overwrite existing install
```

### Windows (PowerShell)

```powershell
.\install.ps1
.\install.ps1 -System -AddToPath
.\install.ps1 -InstallDir "C:\Tools\bin" -AddToPath -Force
```

Installers detect whether `git` is present and offer to install it if missing.

---

## Quick Start

```bash
# Archive all tracked files (default)
gitpack

# Preview what would be archived — no file created
gitpack --dry-run

# Archive only modified files
gitpack -m modified -o changes.zip

# Archive everything in the directory (no Git needed)
gitpack --no-git -o backup.zip
```

---

## File Selection Modes

| Mode        | What it archives                          |
|-------------|-------------------------------------------|
| `tracked`   | Git-tracked files (default)               |
| `staged`    | Files staged for the next commit          |
| `modified`  | Modified but not yet staged               |
| `untracked` | Untracked, non-ignored files              |
| `ignored`   | Files ignored by `.gitignore`             |
| `all`       | tracked + untracked                       |
| `everything`| All files except `.git/` (filesystem)     |

---

## Options

### File Selection

| Flag | Description |
|------|-------------|
| `-m, --mode <mode>` | File collection mode (default: `tracked`) |
| `--since <ref>` | Files changed since a commit or ref |
| `--diff <c1> <c2>` | Files changed between two commits |
| `--include <regex>` | Keep files matching pattern (repeatable) |
| `--exclude <regex>` | Drop files matching pattern (repeatable) |
| `--max-size <size>` | Drop files larger than size (e.g. `1M`, `500K`) |
| `--use-select` | Enable `.gitpackselect` opt-in list |
| `--select-file <file>` | Custom select file (enables select mode) |
| `--ignore-file <file>` | Custom ignore file (default: `.gitpackignore`) |
| `--no-empty` | Exit with error if no files are selected |

### Output

| Flag | Description |
|------|-------------|
| `-o, --output <file>` | Output path (auto-named if omitted) |
| `--format zip\|tar.gz` | Archive format (default: `zip`) |
| `--prefix <path>` | Path prefix added inside the archive |
| `--timestamp` | Append ISO timestamp to output filename |
| `--overwrite` | Overwrite existing output without prompting |

### Behavior

| Flag | Description |
|------|-------------|
| `--dry-run` | Print selected files; do not create archive |
| `--list` | Like `--dry-run` with a file count summary |
| `--no-git` | Scan filesystem instead of using Git |
| `--init-if-missing` | Run `git init` if not in a repository |
| `--base-dir <dir>` | Run from a different directory |

### Display

| Flag | Description |
|------|-------------|
| `--verbose` | Show detailed progress |
| `--quiet` | Suppress all non-error output |
| `--no-color` | Disable color output |
| `-V, --version` | Print version |
| `-h, --help` | Show help |

---

## Project Filter Files

### `.gitpackignore`

Regex patterns — one per line — to exclude from every run:

```text
# Comments are ignored
node_modules
\.log$
\.env$
dist/
```

Applied automatically when present. Disable with `--ignore-file /dev/null`.

### `.gitpackselect`

Explicit opt-in list. Can be exact paths or regex patterns:

```text
src/main.go
^docs/.*\.md$
Makefile
```

Enable with `--use-select`. Cannot be used together with `.gitpackignore`.

---

## Examples

```bash
# Archive tracked files → gitpack.zip (default output name)
gitpack

# Archive staged files only
gitpack -m staged -o staged.zip

# Dry-run: list untracked files with count
gitpack --list -m untracked

# All Go files, skip vendor directory
gitpack --include '\.go$' --exclude vendor -o app.zip

# Files changed in the last commit
gitpack --diff HEAD~1 HEAD -o patch.zip

# Files changed in the last 3 commits
gitpack --since HEAD~3 -o recent.zip

# Add a path prefix inside the archive
gitpack --prefix myapp/ -m tracked -o release.zip

# Timestamped filename: gitpack-20260101T120000.zip
gitpack --timestamp

# tar.gz, no git required, skip files over 1MB
gitpack --no-git --format tar.gz --max-size 1M -o backup.tar.gz

# Quiet mode (for CI/scripts)
gitpack --quiet -m tracked -o dist.zip
```

---

## Uninstall

### Linux / macOS

```bash
./uninstall.sh          # find and remove gitpack from PATH
./uninstall.sh --all    # remove all discovered copies
./uninstall.sh -y       # no confirmation prompt
```

### Windows

```powershell
.\uninstall.ps1
.\uninstall.ps1 -All -RemoveFromPath -Yes
```

---

## Testing

```bash
./tests/test_gitpack.sh
```

---

## Files

| File | Description |
|------|-------------|
| `gitpack` | Main CLI script |
| `install.sh` | Linux/macOS installer |
| `install.ps1` | Windows installer |
| `uninstall.sh` | Linux/macOS uninstaller |
| `uninstall.ps1` | Windows uninstaller |
| `tests/test_gitpack.sh` | Automated test suite |
| `.gitpackignore` | (your project) Exclusion patterns |
| `.gitpackselect` | (your project) Opt-in file list |
| `GUIDE.md` | Full reference guide |
| `agent.md` | Agent/automation instructions |
