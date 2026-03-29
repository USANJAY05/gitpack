# gitpack — Complete Guide

This guide covers everything from basic use to advanced scenarios.

---

## What gitpack Does

`gitpack` creates a `.zip` or `.tar.gz` archive from files in your project.
What makes it different from plain `zip` or `tar`:

- **Git-aware**: selects files by Git status (tracked, staged, modified, etc.)
- **Commit range diffing**: archive only what changed between two commits
- **Regex filters**: include/exclude by pattern, size cap, or select lists
- **Non-Git mode**: works on any directory with `--no-git`
- **Cross-platform**: Linux, macOS, Windows (Git Bash / WSL / MSYS / Cygwin)

---

## Command Syntax

```bash
gitpack [options]
```

Running with no arguments archives all tracked files into `gitpack.zip`.

---

## File Selection

### By Git status (`--mode`)

```bash
gitpack -m tracked       # only files tracked by git (default)
gitpack -m staged        # files staged for commit
gitpack -m modified      # modified but not yet staged
gitpack -m untracked     # new files not yet added to git
gitpack -m ignored       # files ignored by .gitignore
gitpack -m all           # tracked + untracked
gitpack -m everything    # everything except .git/ (filesystem scan)
```

### By commit range

```bash
# Files changed since HEAD~3
gitpack --since HEAD~3 -o recent.zip

# Files changed between two specific commits
gitpack --diff abc1234 def5678 -o between.zip

# Files changed in the last commit
gitpack --diff HEAD~1 HEAD -o last-commit.zip

# Files changed since a branch diverged
gitpack --since main -o my-changes.zip
```

Files are checked for existence before inclusion — deleted files are skipped.

### Without Git

```bash
gitpack --no-git -m everything -o backup.zip
```

Scans the filesystem directly. All modes except `everything` fall back to a
full filesystem scan when `--no-git` is set.

---

## Output Naming

```bash
gitpack                             # → gitpack.zip
gitpack --format tar.gz             # → gitpack.tar.gz
gitpack -o release.zip              # → release.zip
gitpack --timestamp                 # → gitpack-20260101T120000.zip
gitpack --timestamp --format tar.gz # → gitpack-20260101T120000.tar.gz
```

If the output file already exists, gitpack asks for confirmation unless
`--overwrite` is passed (or stdin is not a TTY, e.g. in CI).

---

## Filters

### Regex include/exclude

```bash
# Only .go files
gitpack --include '\.go$'

# Exclude test files
gitpack --exclude '_test\.go$'

# Combine: .go files, skip vendor
gitpack --include '\.go$' --exclude '^vendor/'

# Multiple patterns (repeatable)
gitpack --include '\.go$' --include '\.mod$' --exclude 'testdata'
```

Patterns are extended regex (`grep -E`). Include is applied before exclude.

### Size cap

```bash
gitpack --max-size 1M           # skip files over 1 MB
gitpack --max-size 500K         # skip files over 500 KB
gitpack --max-size 2G           # skip files over 2 GB
gitpack --max-size 102400       # skip files over 100 KB (raw bytes)
```

Accepted units: `K`/`KB`, `M`/`MB`, `G`/`GB`, or raw bytes.

---

## Project Filter Files

### `.gitpackignore`

Drop patterns applied automatically every time gitpack runs in a directory
that contains this file:

```text
# Ignore build artifacts
dist/
build/

# Ignore log and env files
\.log$
\.env$

# Ignore lock files
package-lock\.json$
yarn\.lock$
```

- One regex pattern per line
- Lines starting with `#` and blank lines are ignored
- Applied before `--include`/`--exclude` flags

Override the filename:

```bash
gitpack --ignore-file .myignore
```

Disable entirely:

```bash
gitpack --ignore-file /dev/null
```

### `.gitpackselect`

Explicit opt-in list. Only matching files are archived:

```text
# Exact paths
src/main.go
go.mod
Makefile

# Regex patterns
^docs/.*\.md$
^config/.*\.yaml$
```

Enable:

```bash
gitpack --use-select
gitpack --select-file deploy-files.txt
```

**Note:** `.gitpackselect` and `.gitpackignore` cannot be used together.
If both files exist and `--use-select` is active, gitpack exits with an error.

---

## Archive Options

### Path prefix

Adds a prefix directory inside the archive:

```bash
gitpack --prefix myapp/ -m tracked -o myapp.zip
```

Contents will be at `myapp/src/main.go`, `myapp/README.md`, etc. instead of
the root.

### Format

```bash
gitpack --format zip      # default
gitpack --format tar.gz
```

`tar.gz` requires `tar`. `zip` requires `zip` (or PowerShell on Windows).

---

## Preview Modes

```bash
# Print file list, no archive created
gitpack --dry-run

# Print file list + total count
gitpack --list

# Verbose: show progress and details while archiving
gitpack --verbose

# Quiet: suppress all output except errors (for CI)
gitpack --quiet
```

---

## Repository Options

```bash
# Run in a different directory
gitpack --base-dir /path/to/project -m tracked -o project.zip

# Initialize Git if not already in a repo
gitpack --init-if-missing -m tracked

# Skip Git entirely
gitpack --no-git -m everything -o full-backup.zip
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Package release
  run: |
    gitpack -m tracked --quiet -o release.zip --overwrite

- name: Package changed files
  run: |
    gitpack --diff ${{ github.event.before }} ${{ github.sha }} \
            --quiet -o changes.zip --overwrite
```

### General CI tips

- Use `--quiet` to suppress progress output
- Use `--overwrite` to avoid the interactive prompt
- Use `--no-empty` to fail the build if nothing matched
- Use `--timestamp` to create unique filenames per run

---

## Common Scenarios

### Release packaging

```bash
gitpack -m tracked --prefix myapp-v1.2.0/ -o myapp-v1.2.0.zip
```

### Patch delivery

```bash
gitpack --diff v1.1.0 v1.2.0 -o patch-v1.2.0.zip
```

### Deploying only config files

```bash
# .gitpackselect:
# ^config/
# ^docker-compose\.yml$

gitpack --use-select --quiet -o config-deploy.zip
```

### Backup ignoring large assets

```bash
gitpack --no-git --max-size 5M --exclude '^assets/' -o backup.zip
```

### Snapshot with timestamp

```bash
gitpack -m everything --timestamp --no-git
# → gitpack-20260330T091500.zip
```

---

## Troubleshooting

### "Not a Git repository"

Use one of:

```bash
gitpack --no-git
gitpack --init-if-missing
gitpack --base-dir /path/to/git-repo
```

### "No files selected"

- Check the mode: `gitpack --list -m <mode>`
- Review `.gitpackignore` patterns
- Check `--include`/`--exclude` regex

### Output file already exists

Use `--overwrite` or delete the existing file first.

### "zip command not found"

```bash
# Debian/Ubuntu
sudo apt install zip

# macOS
brew install zip

# Or switch to tar.gz
gitpack --format tar.gz
```

### Path not in PATH after install

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add to `~/.bashrc`, `~/.zshrc`, or your shell profile.

---

## Learning Path

1. `gitpack --help` — read the reference
2. `gitpack --list -m tracked` — preview default selection
3. `gitpack -m tracked -o code.zip` — first real archive
4. Add `--include`/`--exclude` to filter
5. Try `--diff HEAD~1 HEAD` to archive a recent change
6. Create a `.gitpackignore` for permanent exclusions
