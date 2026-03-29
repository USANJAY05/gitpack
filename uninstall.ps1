param(
  [Alias("Path")]
  [string]$InstallDir,
  [switch]$System,
  [switch]$All,
  [switch]$RemoveFromPath,
  [switch]$Yes,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
  @"
gitpack uninstaller (Windows)

Usage:
  .\uninstall.ps1 [options]

Options:
  -InstallDir <dir>   Uninstall from specific directory
  -Path <dir>         Alias of -InstallDir
  -System             Prefer Program Files target if InstallDir is not provided
  -All                Remove from all discovered install directories
  -RemoveFromPath     Remove uninstall directory entries from PATH
  -Yes                Skip confirmation prompts
  -Help               Show this help
"@
}

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message"
}

function Write-Warn([string]$Message) {
  Write-Warning $Message
}

function Is-Yes([string]$Answer) {
  if ([string]::IsNullOrWhiteSpace($Answer)) {
    return $true
  }
  return $Answer -match '^(?i:y|yes)$'
}

function Confirm-OrExit([string]$Prompt) {
  if ($Yes) {
    return
  }

  $answer = Read-Host "$Prompt [Y/n]"
  if (-not (Is-Yes $answer)) {
    throw "Aborted"
  }
}

function Get-PathEntries([string]$scope) {
  $value = [Environment]::GetEnvironmentVariable("Path", $scope)
  if ([string]::IsNullOrWhiteSpace($value)) {
    return @()
  }

  return @($value -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Normalize-Dir([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return $null
  }

  try {
    return (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
  }
  catch {
    return [IO.Path]::GetFullPath($PathValue)
  }
}

function Get-DiscoveredInstallDirs {
  $dirs = New-Object System.Collections.Generic.List[string]

  if ($InstallDir) {
    $dirs.Add((Normalize-Dir $InstallDir))
    return $dirs | Select-Object -Unique
  }

  $defaultUser = Join-Path $env:LOCALAPPDATA "gitpack\bin"
  $defaultSystem = Join-Path $env:ProgramFiles "gitpack\bin"

  if ($System) {
    $dirs.Add((Normalize-Dir $defaultSystem))
  }
  else {
    $dirs.Add((Normalize-Dir $defaultUser))
    $dirs.Add((Normalize-Dir $defaultSystem))
  }

  $cmd = Get-Command gitpack -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Path) {
    $dirs.Add((Normalize-Dir (Split-Path -Parent $cmd.Path)))
  }

  foreach ($scope in @("User", "Machine")) {
    foreach ($entry in Get-PathEntries $scope) {
      $norm = Normalize-Dir $entry
      if (-not $norm) {
        continue
      }

      if ((Test-Path -LiteralPath (Join-Path $norm "gitpack")) -or (Test-Path -LiteralPath (Join-Path $norm "gitpack.cmd"))) {
        $dirs.Add($norm)
      }
    }
  }

  return $dirs | Where-Object { $_ } | Select-Object -Unique
}

function Remove-FromPath([string[]]$DirsToRemove, [string]$scope) {
  $existing = Get-PathEntries $scope
  if ($existing.Count -eq 0) {
    return
  }

  $removeSet = @{}
  foreach ($dir in $DirsToRemove) {
    $removeSet[(Normalize-Dir $dir).ToLowerInvariant()] = $true
  }

  $filtered = New-Object System.Collections.Generic.List[string]
  foreach ($entry in $existing) {
    $normalizedEntry = (Normalize-Dir $entry).ToLowerInvariant()
    if (-not $removeSet.ContainsKey($normalizedEntry)) {
      $filtered.Add($entry)
    }
  }

  $newValue = $filtered -join ';'
  [Environment]::SetEnvironmentVariable("Path", $newValue, $scope)
}

if ($Help) {
  Show-Help
  exit 0
}

$installDirs = @()
$installDirs += Get-DiscoveredInstallDirs

if (-not $installDirs -or $installDirs.Count -eq 0) {
  Write-Warn "No gitpack installation directories found."
  exit 0
}

if (-not $All -and $installDirs.Count -gt 1) {
  $installDirs = @($installDirs[0])
}

Write-Info "Found target directory(s):"
$installDirs | ForEach-Object { Write-Host "  $_" }

if ($installDirs.Count -eq 1) {
  Confirm-OrExit "Remove gitpack from this directory?"
}
else {
  Confirm-OrExit "Remove gitpack from all discovered directories?"
}

$removedAny = $false
foreach ($dir in $installDirs) {
  foreach ($name in @("gitpack", "gitpack.cmd")) {
    $target = Join-Path $dir $name
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath $target -Force
      Write-Info "Removed: $target"
      $removedAny = $true
    }
  }

  if (Test-Path -LiteralPath $dir) {
    $leftovers = Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue
    if (-not $leftovers) {
      Remove-Item -LiteralPath $dir -Force
      Write-Info "Removed empty directory: $dir"
    }
  }
}

if ($RemoveFromPath) {
  Remove-FromPath -DirsToRemove $installDirs -scope "User"
  Remove-FromPath -DirsToRemove $installDirs -scope "Machine"
  Write-Info "Removed directory entries from PATH where present"
}

if (-not $removedAny) {
  Write-Warn "No gitpack binary files were found in discovered directories."
}

Write-Info "Uninstall complete"
Write-Host "Open a new terminal to refresh PATH changes."
