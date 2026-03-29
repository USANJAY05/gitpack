param(
  [Alias("Path")]
  [string]$InstallDir,
  [switch]$AddToPath,
  [switch]$System,
  [switch]$Force,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
  @"
gitpack installer (Windows)

Usage:
  .\install.ps1 [options]

Options:
  -InstallDir <dir>  Install directory (contains gitpack and gitpack.cmd)
  -Path <dir>        Alias of -InstallDir
  -AddToPath         Add install directory to PATH
  -System            Install for all users (Program Files path)
  -Force             Overwrite existing installation
  -Help              Show this help
"@
}

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message"
}

function Write-Warn([string]$Message) {
  Write-Warning $Message
}

function Get-GitInstallCommand {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    return "winget install --id Git.Git -e --source winget"
  }
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    return "choco install git -y"
  }
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    return "scoop install git"
  }
  return $null
}

function Is-Yes([string]$Answer) {
  if ([string]::IsNullOrWhiteSpace($Answer)) {
    return $true
  }
  return $Answer -match '^(?i:y|yes)$'
}

function Ensure-GitInstalled {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    return
  }

  Write-Warn "git is not installed, but gitpack requires git for repository-aware modes."
  $installCmd = Get-GitInstallCommand

  if ($installCmd) {
    Write-Host "Install Git with this command:"
    Write-Host "  $installCmd"

    $reply = Read-Host "Run this command now? [Y/n]"
    if (Is-Yes $reply) {
      Invoke-Expression $installCmd
    }
  }

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is still not available. Install git, then re-run installer."
  }
}

if ($Help) {
  Show-Help
  exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir "gitpack"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Cannot find gitpack at: $source"
}

Ensure-GitInstalled

if (-not $InstallDir -or $InstallDir.Trim().Length -eq 0) {
  if ($System) {
    $InstallDir = Join-Path $env:ProgramFiles "gitpack\bin"
  }
  else {
    $InstallDir = Join-Path $env:LOCALAPPDATA "gitpack\bin"
  }
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

$target = Join-Path $InstallDir "gitpack"
$launcher = Join-Path $InstallDir "gitpack.cmd"

if ((Test-Path -LiteralPath $target) -and (-not $Force)) {
  throw "Target already exists: $target (use -Force to overwrite)"
}

Copy-Item -LiteralPath $source -Destination $target -Force

$cmdContent = @"
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "BASH_EXE="

if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE for %%I in (bash.exe) do set "BASH_EXE=%%~$PATH:I"

if not defined BASH_EXE (
  echo [ERROR] bash.exe not found. Install Git for Windows and retry.
  exit /b 1
)

"%BASH_EXE%" "%SCRIPT_DIR%gitpack" %*
endlocal
"@

Set-Content -LiteralPath $launcher -Value $cmdContent -Encoding Ascii

if ($AddToPath) {
  $pathTarget = if ($System) { "Machine" } else { "User" }
  $existingPath = [Environment]::GetEnvironmentVariable("Path", $pathTarget)

  if ([string]::IsNullOrWhiteSpace($existingPath)) {
    [Environment]::SetEnvironmentVariable("Path", $InstallDir, $pathTarget)
    Write-Info "Added to PATH ($pathTarget): $InstallDir"
  }
  elseif ((";" + $existingPath + ";") -notlike "*;$InstallDir;*") {
    [Environment]::SetEnvironmentVariable("Path", "$existingPath;$InstallDir", $pathTarget)
    Write-Info "Added to PATH ($pathTarget): $InstallDir"
  }
  else {
    Write-Info "PATH already contains: $InstallDir"
  }
}
else {
  Write-Warn "Install directory is not added to PATH automatically."
  Write-Host "Re-run with -AddToPath or add manually: $InstallDir"
}

Write-Info "Installed: $target"
Write-Info "Launcher: $launcher"
Write-Host "Open a new terminal and run: gitpack --help"
