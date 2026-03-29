#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for gitpack on Windows.

.DESCRIPTION
    Installs the gitpack CLI to a directory of your choice and optionally
    adds it to your PATH.

.PARAMETER InstallDir
    Full path to the directory where gitpack should be installed.
    Overrides -Path and -Prefix.

.PARAMETER Path
    Alias for -InstallDir.

.PARAMETER Prefix
    Install under <Prefix>\bin.

.PARAMETER System
    Install system-wide to C:\Program Files\gitpack\bin.
    Requires an elevated (administrator) session.

.PARAMETER AddToPath
    Add the install directory to the current user's PATH environment variable.

.PARAMETER DryRun
    Print what would be done without making any changes.

.PARAMETER Help
    Show this help message and exit.

.EXAMPLE
    .\install.ps1 -Help

.EXAMPLE
    .\install.ps1 -System -AddToPath

.EXAMPLE
    .\install.ps1 -InstallDir "$Env:USERPROFILE\.local\bin" -AddToPath

.EXAMPLE
    .\install.ps1 -Prefix "C:\opt" -DryRun
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Custom')]
    [string] $InstallDir,

    [Parameter(ParameterSetName = 'Custom')]
    [string] $Path,

    [Parameter(ParameterSetName = 'Custom')]
    [string] $Prefix,

    [Parameter(ParameterSetName = 'System')]
    [switch] $System,

    [switch] $AddToPath,
    [switch] $DryRun,
    [switch] $Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallerVersion = '1.0.0'
$BinaryName       = 'gitpack'
$ScriptDir        = $PSScriptRoot

# ── Help ─────────────────────────────────────────────────────────────────────────
if ($Help) {
    Get-Help -Full $PSCommandPath
    exit 0
}

# ── Helper functions ──────────────────────────────────────────────────────────────
function Write-Info  { param([string]$Msg) Write-Host "[install] $Msg" -ForegroundColor Green  }
function Write-Warn  { param([string]$Msg) Write-Host "[warn]    $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "[error]   $Msg" -ForegroundColor Red    }

function Invoke-Step {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Host "[dry-run] $Description" -ForegroundColor Yellow
    } else {
        & $Action
    }
}

function Assert-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Err "-System requires an elevated (Run as Administrator) PowerShell session."
        exit 1
    }
}

# ── Conflict detection ────────────────────────────────────────────────────────────
$flagsSet = 0
if ($InstallDir) { $flagsSet++ }
if ($Path)       { $flagsSet++ }
if ($Prefix)     { $flagsSet++ }
if ($System)     { $flagsSet++ }

if ($flagsSet -gt 1) {
    Write-Err "Conflicting options: use only one of -InstallDir, -Path, -Prefix, -System."
    exit 1
}

# ── Resolve destination directory ─────────────────────────────────────────────────
function Resolve-Dest {
    if ($InstallDir) { return $InstallDir }
    if ($Path)       { return $Path }
    if ($Prefix)     { return Join-Path $Prefix 'bin' }
    if ($System) {
        Assert-Admin
        return Join-Path $Env:ProgramFiles 'gitpack\bin'
    }

    # Interactive prompt
    Write-Host ''
    Write-Host 'Where should gitpack be installed?'
    Write-Host '  1) User directory  (%USERPROFILE%\.local\bin)  [default]'
    Write-Host '  2) System-wide     (C:\Program Files\gitpack\bin)  [requires admin]'
    Write-Host '  3) Custom path'
    $choice = Read-Host 'Choice [1]'
    switch ($choice) {
        '2' {
            Assert-Admin
            return Join-Path $Env:ProgramFiles 'gitpack\bin'
        }
        '3' {
            $custom = Read-Host 'Enter destination directory'
            if (-not $custom) { Write-Err 'No directory provided.'; exit 1 }
            return $custom
        }
        default {
            return Join-Path $Env:USERPROFILE '.local\bin'
        }
    }
}

$Dest   = Resolve-Dest
$Source = Join-Path $ScriptDir $BinaryName

# ── Pre-flight checks ─────────────────────────────────────────────────────────────
if (-not (Test-Path $Source)) {
    Write-Err "Binary not found: $Source"
    exit 1
}

Write-Info "Source : $Source"
Write-Info "Dest   : $Dest\$BinaryName"
if ($DryRun) { Write-Warn 'Dry-run mode — no changes will be made.' }

# ── Install ───────────────────────────────────────────────────────────────────────
Invoke-Step "Create directory: $Dest" {
    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }
}

Invoke-Step "Copy $BinaryName -> $Dest" {
    Copy-Item -Path $Source -Destination (Join-Path $Dest $BinaryName) -Force
}

Write-Info "Installed $BinaryName -> $Dest\$BinaryName"

# ── PATH management ───────────────────────────────────────────────────────────────
if ($AddToPath) {
    Invoke-Step "Add $Dest to user PATH" {
        $scope       = if ($System) { 'Machine' } else { 'User' }
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', $scope)
        if ($currentPath -notlike "*$Dest*") {
            [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$Dest", $scope)
            Write-Info "Added $Dest to $scope PATH."
        } else {
            Write-Info "$Dest is already in $scope PATH."
        }
    }
} else {
    $envPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($envPath -notlike "*$Dest*") {
        Write-Warn "$Dest is not in your PATH."
        Write-Warn "Re-run with -AddToPath to add it automatically, or add it manually:"
        Write-Warn "  `$Env:PATH += `";$Dest`""
    }
}

Write-Info "Done. Run 'gitpack --help' to get started."
