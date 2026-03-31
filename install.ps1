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
    [switch]$Uninstall,

    [Parameter(HelpMessage = 'Override the workspace root directory. Defaults to 3 levels above the script location.')]
    [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Resolve paths -----------------------------------------------------------
$SpeckitRoot = $PSScriptRoot
if (-not $SpeckitRoot) { $SpeckitRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Resolve workspace root: use parameter if provided, otherwise walk up 3 levels
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = (Resolve-Path (Join-Path $SpeckitRoot '..\..\..'))
}
else {
    $WorkspaceRoot = (Resolve-Path $WorkspaceRoot)
}

# Validate workspace root looks like a git repository
if (-not (Test-Path (Join-Path $WorkspaceRoot '.git'))) {
    Write-Warning "Workspace root '$WorkspaceRoot' does not contain a .git directory. Verify the path is correct."
}
$GithubDir  = Join-Path $WorkspaceRoot '.github'
$SkillsDir  = Join-Path $GithubDir 'skills'
$AgentsDir  = Join-Path $GithubDir 'agents'

# Determine whether speckit root is already inside .github/skills/speckit/
$ExpectedSpeckitDir = Join-Path $SkillsDir 'speckit'
$SpeckitIsExternal  = ($SpeckitRoot -ne (Resolve-Path $ExpectedSpeckitDir -ErrorAction SilentlyContinue))

# --- Pull latest submodule ----------------------------------------------------
$gitModulesPath = Join-Path $WorkspaceRoot '.gitmodules'
$submodulePath = '.github/skills/speckit'
if ((Test-Path $gitModulesPath) -and -not $Uninstall) {
    $gitModulesContent = Get-Content $gitModulesPath -Raw -ErrorAction SilentlyContinue
    if ($gitModulesContent -match [regex]::Escape($submodulePath)) {
        Write-Host "Pulling latest speckit from remote..." -ForegroundColor Cyan
        Push-Location $WorkspaceRoot
        try {
            git submodule update --remote --merge -- $submodulePath 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        }
        finally {
            Pop-Location
        }
        Write-Host ''
    }
}

# --- Definitions -------------------------------------------------------------
# Sub-skills: link into .github/skills/
$Skills = @(
    'speckit-specify'
    'speckit-plan'
    'speckit-implement'
    'speckit-test'
    'speckit-e2e'
    'speckit-retro'
    'speckit-constitution'
    'speckit-verify'
)

# Subagents: link into .github/agents/
$Agents = @(
    'speckit-codebase-scanner'
    'speckit-living-docs-loader'
    'speckit-e2e-recorder'
    'speckit-pipeline-checker'
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

    # Remove speckit root link (if it was created by installer)
    if (Test-Path $ExpectedSpeckitDir) {
        $rootItem = Get-Item $ExpectedSpeckitDir -Force
        if ($rootItem.LinkType -eq 'Junction' -or $rootItem.LinkType -eq 'SymbolicLink') {
            Remove-Link $ExpectedSpeckitDir
        }
    }

    Write-Host "Skills:" -ForegroundColor Cyan
    foreach ($skill in $Skills) {
        Remove-Link (Join-Path $SkillsDir $skill)
    }

    Write-Host ''
    Write-Host "Agents:" -ForegroundColor Cyan
    foreach ($agent in $Agents) {
        Remove-Link (Join-Path $AgentsDir $agent)
    }

    # Remove manifest
    $manifestPath = Join-Path $GithubDir 'speckit-manifest.json'
    if (Test-Path $manifestPath) {
        Remove-Item $manifestPath -Force
        Write-Host ''
        Write-Host "  [removed] .github/speckit-manifest.json" -ForegroundColor Yellow
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

# --- Link speckit root into .github/skills/speckit/ (if external) -------------
if ($SpeckitIsExternal) {
    Write-Host "Speckit root (.github/skills/speckit/):" -ForegroundColor Cyan
    New-Link -LinkPath $ExpectedSpeckitDir -TargetPath $SpeckitRoot
    Write-Host ''
}

Write-Host "Skills (.github/skills/):" -ForegroundColor Cyan
foreach ($skill in $Skills) {
    $target = Join-Path (Join-Path $SpeckitRoot 'skills') $skill
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
    $target = Join-Path (Join-Path $SpeckitRoot 'agents') $agent
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
if ($SpeckitIsExternal) { $linksToIgnore += ".github/skills/speckit" }
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

# --- Write manifest -----------------------------------------------------------
$manifestPath = Join-Path $GithubDir 'speckit-manifest.json'

# Resolve submodule commit hash
$submoduleHash = $null
Push-Location $SpeckitRoot
try {
    $submoduleHash = (git rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { $submoduleHash = $null }
}
catch { $submoduleHash = $null }
finally { Pop-Location }

$linkedSkills = @()
foreach ($skill in $Skills) {
    $linkPath = Join-Path $SkillsDir $skill
    if (Test-Path $linkPath) {
        $linkedSkills += @{
            name   = $skill
            link   = ".github/skills/$skill"
            target = ".github/skills/speckit/skills/$skill"
        }
    }
}

$linkedAgents = @()
foreach ($agent in $Agents) {
    $linkPath = Join-Path $AgentsDir $agent
    if (Test-Path $linkPath) {
        $linkedAgents += @{
            name   = $agent
            link   = ".github/agents/$agent"
            target = ".github/skills/speckit/agents/$agent"
        }
    }
}

$manifest = @{
    version            = 1
    installedAt        = (Get-Date -Format 'o')
    submoduleHash      = $submoduleHash
    submodulePath      = $submodulePath
    speckitRootLinked  = $SpeckitIsExternal
    skills             = $linkedSkills
    agents             = $linkedAgents
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Host ''
Write-Host "Manifest written to .github/speckit-manifest.json" -ForegroundColor Cyan
if ($submoduleHash) {
    Write-Host "  Submodule hash: $submoduleHash" -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "Done. Speckit is installed." -ForegroundColor Green
Write-Host ''
Write-Host "The router skill (speckit) is at .github/skills/speckit/SKILL.md" -ForegroundColor DarkGray
Write-Host "Sub-skills and agents are linked for VS Code discovery." -ForegroundColor DarkGray
Write-Host ''
