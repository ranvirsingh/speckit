<#
.SYNOPSIS
    Installs speckit skills and subagents into the standard VS Code discovery paths.

.DESCRIPTION
    Creates directory junctions (Windows) or symlinks (macOS/Linux) from speckit
    sub-skill and subagent directories into .github/skills/ and .github/agents/
    so VS Code discovers them without manual settings.json configuration.

    Run this after adding speckit as a git submodule:
      git submodule add <url> .github/skills/speckit
      pwsh .github/skills/speckit/install.ps1

    The script is idempotent -- safe to run multiple times.

.PARAMETER Uninstall
    Remove all speckit links from .github/skills/ and .github/agents/.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Resolve paths -----------------------------------------------------------
$SpeckitRoot = $PSScriptRoot
if (-not $SpeckitRoot) { $SpeckitRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Walk up to workspace root: install.ps1 sits at .github/skills/speckit/
$WorkspaceRoot = (Resolve-Path (Join-Path $SpeckitRoot '..\..\..'))

$SkillsDir = Join-Path (Join-Path $WorkspaceRoot '.github') 'skills'
$AgentsDir = Join-Path (Join-Path $WorkspaceRoot '.github') 'agents'

# --- Definitions -------------------------------------------------------------
# Sub-skills: link into .github/skills/
$Skills = @(
    'speckit-specify'
    'speckit-plan'
    'speckit-implement'
    'speckit-retro'
    'speckit-constitution'
)

# Subagents: link into .github/agents/
$Agents = @(
    'speckit-codebase-scanner'
    'speckit-living-docs-loader'
)

# --- Helpers ------------------------------------------------------------------
function New-Link {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath -Force
        $isLink = $item.LinkType -eq 'Junction' -or $item.LinkType -eq 'SymbolicLink'
        if ($isLink) {
            Write-Host "  [skip] Already linked: $LinkPath" -ForegroundColor DarkGray
            return
        }
        else {
            Write-Warning "  [conflict] $LinkPath exists but is not a link. Skipping."
            return
        }
    }

    $isWin = ($env:OS -eq 'Windows_NT')
    if ($isWin) {
        # Directory junction -- no admin rights needed on Windows
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
    }
    else {
        # Symlink on macOS/Linux
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
    }

    Write-Host "  [link] $LinkPath -> $TargetPath" -ForegroundColor Green
}

function Remove-Link {
    param([string]$LinkPath)

    if (-not (Test-Path $LinkPath)) {
        Write-Host "  [skip] Not found: $LinkPath" -ForegroundColor DarkGray
        return
    }

    $item = Get-Item $LinkPath -Force
    $isLink = $item.LinkType -eq 'Junction' -or $item.LinkType -eq 'SymbolicLink'
    if (-not $isLink) {
        Write-Warning "  [skip] $LinkPath is not a link. Not removing."
        return
    }

    # Remove the junction/symlink (not the target)
    $item.Delete()
    Write-Host "  [removed] $LinkPath" -ForegroundColor Yellow
}

# --- Main ---------------------------------------------------------------------
Write-Host ''
Write-Host "Speckit Installer" -ForegroundColor Cyan
Write-Host "  Workspace root : $WorkspaceRoot"
Write-Host "  Speckit root   : $SpeckitRoot"
Write-Host ''

if ($Uninstall) {
    Write-Host "Removing speckit links..." -ForegroundColor Yellow
    Write-Host ''

    Write-Host "Skills:" -ForegroundColor Cyan
    foreach ($skill in $Skills) {
        Remove-Link (Join-Path $SkillsDir $skill)
    }

    Write-Host ''
    Write-Host "Agents:" -ForegroundColor Cyan
    foreach ($agent in $Agents) {
        Remove-Link (Join-Path $AgentsDir $agent)
    }

    Write-Host ''
    Write-Host "Done. Speckit links removed." -ForegroundColor Green
    return
}

# Install
Write-Host "Installing speckit links..." -ForegroundColor Cyan
Write-Host ''

# Ensure target directories exist
if (-not (Test-Path $SkillsDir)) { New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null }
if (-not (Test-Path $AgentsDir)) { New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null }

Write-Host "Skills (.github/skills/):" -ForegroundColor Cyan
foreach ($skill in $Skills) {
    $target = Join-Path $SpeckitRoot $skill
    $link = Join-Path $SkillsDir $skill
    if (-not (Test-Path $target)) {
        Write-Warning "  [missing] Source not found: $target"
        continue
    }
    New-Link -LinkPath $link -TargetPath $target
}

Write-Host ''
Write-Host "Agents (.github/agents/):" -ForegroundColor Cyan
foreach ($agent in $Agents) {
    $target = Join-Path $SpeckitRoot $agent
    $link = Join-Path $AgentsDir $agent
    if (-not (Test-Path $target)) {
        Write-Warning "  [missing] Source not found: $target"
        continue
    }
    New-Link -LinkPath $link -TargetPath $target
}

# --- Git ignore the links ----------------------------------------------------
$gitignorePath = Join-Path $WorkspaceRoot '.gitignore'
$linksToIgnore = @()
foreach ($skill in $Skills) { $linksToIgnore += ".github/skills/$skill" }
foreach ($agent in $Agents) { $linksToIgnore += ".github/agents/$agent" }

$existingIgnore = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { '' }
$newEntries = @()
foreach ($entry in $linksToIgnore) {
    if ($existingIgnore -notmatch [regex]::Escape($entry)) {
        $newEntries += $entry
    }
}

if ($newEntries.Count -gt 0) {
    Write-Host ''
    Write-Host "Updating .gitignore with speckit links..." -ForegroundColor Cyan
    $block = "`n# speckit links (created by install.ps1)`n"
    $block += ($newEntries -join "`n") + "`n"
    Add-Content -Path $gitignorePath -Value $block -NoNewline
    Write-Host "  [updated] .gitignore - added $($newEntries.Count) entries" -ForegroundColor Green
}

Write-Host ''
Write-Host "Done. Speckit is installed." -ForegroundColor Green
Write-Host ''
Write-Host "The router skill (speckit) is at .github/skills/speckit/SKILL.md" -ForegroundColor DarkGray
Write-Host "Sub-skills and agents are linked for VS Code discovery." -ForegroundColor DarkGray
Write-Host ''
