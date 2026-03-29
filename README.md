# gitpack

**gitpack** is a minimal, Git-based package manager for developers who want a
simple, scriptable way to install and keep CLI tools in sync across Linux,
macOS, and Windows.  It ships as a single Bash script (`gitpack`) with
companion installers (`install.sh` and `install.ps1`) so that bootstrapping
a new machine takes one command.

---

## Features

- **Simple CLI** — one script, a handful of flags, no daemon required.
- **Dry-run safety** — preview every action before it touches your system with
  `--dry-run`.
- **Git-optional** — use `--no-git` to skip all network/git operations during
  testing or offline installs.
- **Cross-platform installers** — `install.sh` targets Linux/macOS;
  `install.ps1` targets Windows PowerShell 5.1+.
- **Flexible install paths** — choose system-wide, per-user, or a fully custom
  directory via flags (no editing of scripts needed).

---

## Quick start

### Linux / macOS

```bash
# Clone or download the repo, then:
bash install.sh --user          # install to ~/.local/bin (no sudo)
bash install.sh --system        # install to /usr/local/bin (may need sudo)
bash install.sh --bin-dir ~/bin # install to a custom directory
```

### Windows (PowerShell)

```powershell
.\install.ps1 -Help                              # show all options
.\install.ps1 -InstallDir "$Env:USERPROFILE\.local\bin" -AddToPath
.\install.ps1 -System -AddToPath                 # requires admin shell
```

---

## gitpack CLI

```
Usage: gitpack [OPTIONS]

Options:
  -m, --mode <mode>   Operation mode: everything | minimal | update
      --dry-run       Print actions without executing them
      --no-git        Skip all git operations
  -h, --help          Show this help message and exit
  -v, --version       Print version and exit
```

### Examples

```bash
gitpack -m everything               # install/update all packages
gitpack -m update                   # update installed packages
gitpack --dry-run --no-git -m everything   # preview without side-effects
```

---

## install.sh options (Linux / macOS)

| Flag | Description |
|---|---|
| `--bin-dir <dir>` | Install binary directly into `<dir>` |
| `--path <dir>` | Alias for `--bin-dir` |
| `--prefix <dir>` | Install under `<dir>/bin` |
| `--system` | System-wide install (`/usr/local/bin`; may need sudo) |
| `--user` | Per-user install (`~/.local/bin`) |
| `--dry-run` | Preview without making changes |
| `-h, --help` | Show help |

---

## install.ps1 options (Windows)

| Flag | Description |
|---|---|
| `-InstallDir <path>` | Install binary into `<path>` |
| `-Path <path>` | Alias for `-InstallDir` |
| `-Prefix <path>` | Install under `<path>\bin` |
| `-System` | System-wide install (`C:\Program Files\gitpack\bin`; requires admin) |
| `-AddToPath` | Add the install directory to the user/system PATH |
| `-DryRun` | Preview without making changes |
| `-Help` | Show help |

---

## Development

```bash
# Syntax-check all scripts
bash -n ./gitpack
bash -n ./install.sh

# Smoke-test the CLI
./gitpack --help
./gitpack --dry-run --no-git -m everything

# Smoke-test the installer
./install.sh --help
./install.sh --dry-run --user

# Windows (if pwsh is available)
pwsh -NoProfile -File ./install.ps1 -Help
```

---

## License

MIT