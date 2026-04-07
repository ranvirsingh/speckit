<#
.SYNOPSIS
    Installs speckit skills and subagents into the standard VS Code discovery paths.

.DESCRIPTION
    Copies speckit sub-skill and subagent directories into .github/skills/ and
    .github/agents/ so VS Code discovers them without manual settings.json
    configuration. A manifest is written to .github/speckit-manifest.json so
    -Update and -Uninstall know exactly which paths to clean up.

    Usage from any project root:
      Invoke-RestMethod https://raw.githubusercontent.com/ranvirsingh/speckit/main/install.ps1 | Invoke-Expression

    Or if already installed:
      powershell -ExecutionPolicy Bypass -File .github/skills/speckit/install.ps1

    The script is idempotent -- safe to run multiple times.

.PARAMETER Uninstall
    Remove all speckit links from .github/skills/ and .github/agents/.

.PARAMETER Force
    Overwrite existing copied directories. Without this flag, the script
    skips directories that already exist at the destination.

.PARAMETER Update
    Download the latest speckit release from GitHub and replace the local copy
    before linking. Requires internet access.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$Update,

    [Parameter(HelpMessage = 'Override the workspace root directory.')]
    [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ForceMode = $Force.IsPresent

# --- Download helper ----------------------------------------------------------
function Get-SpeckitFromGitHub {
    param([string]$DestDir)

    $repoApi = 'https://api.github.com/repos/ranvirsingh/speckit/releases/latest'
    $zipUrl  = $null
    $tag     = $null

    try {
        $release = Invoke-RestMethod -Uri $repoApi -Headers @{ Accept = 'application/vnd.github+json' } -ErrorAction Stop
        $zipUrl  = $release.zipball_url
        $tag     = $release.tag_name
    }
    catch {
        # No releases yet — fall back to main branch zip
        Write-Host '  No releases found, downloading main branch...' -ForegroundColor Yellow
        $zipUrl = 'https://github.com/ranvirsingh/speckit/archive/refs/heads/main.zip'
        $tag    = 'main'
    }

    Write-Host "  Version: $tag" -ForegroundColor DarkGray

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-$tag.zip"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-extract-$([guid]::NewGuid().ToString('N').Substring(0,8))"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -ErrorAction Stop
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

        # GitHub zip contains a single root folder like ranvirsingh-speckit-<hash>/
        $innerDir = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1

        if (Test-Path $DestDir) {
            Remove-Item $DestDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

        Get-ChildItem -Path $innerDir.FullName | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $DestDir $_.Name) -Recurse -Force
        }

        Write-Host "  Extracted to $DestDir" -ForegroundColor Green
        return $tag
    }
    finally {
        if (Test-Path $tempZip -ErrorAction SilentlyContinue) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir -ErrorAction SilentlyContinue) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# --- Resolve paths -----------------------------------------------------------
$SpeckitRoot = $PSScriptRoot
if (-not $SpeckitRoot) { $SpeckitRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Detect bootstrap mode: running from piped input (Invoke-RestMethod | Invoke-Expression) or no valid speckit root
$IsBootstrap = (-not $SpeckitRoot) -or (-not (Test-Path (Join-Path $SpeckitRoot 'SKILL.md')))

if ($IsBootstrap) {
    # Running from web or from a directory that isn't speckit — bootstrap into cwd
    if (-not $WorkspaceRoot) { $WorkspaceRoot = Get-Location }
    $GithubDir  = Join-Path $WorkspaceRoot '.github'
    $SkillsDir  = Join-Path $GithubDir 'skills'
    $SpeckitRoot = Join-Path $SkillsDir 'speckit'

    Write-Host ''
    Write-Host 'Speckit Bootstrap' -ForegroundColor Cyan
    Write-Host "  Workspace root : $WorkspaceRoot"
    Write-Host ''
    Write-Host 'Downloading speckit...' -ForegroundColor Cyan
    $downloadedTag = Get-SpeckitFromGitHub -DestDir $SpeckitRoot
    Write-Host ''
}
else {
    # Running from an existing speckit directory — resolve workspace root
    if (-not $WorkspaceRoot) {
        # Walk up from the speckit source directory to find a .git or *.code-workspace
        $candidate = Split-Path -Parent $SpeckitRoot
        $found = $false
        while ($candidate) {
            $hasGitDir      = Test-Path (Join-Path $candidate '.git')
            $hasWorkspace   = [bool](Get-ChildItem $candidate -Filter '*.code-workspace' -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($hasGitDir -or $hasWorkspace) {
                $WorkspaceRoot = $candidate
                $found = $true
                break
            }
            $parent = Split-Path -Parent $candidate
            if ($parent -eq $candidate) { break }   # reached filesystem root
            $candidate = $parent
        }
        if (-not $found) {
            # Fallback: three levels up from speckit source (legacy behaviour)
            $WorkspaceRoot = (Resolve-Path (Join-Path $SpeckitRoot '..\..\..'))
        }
    }
    else {
        $WorkspaceRoot = (Resolve-Path $WorkspaceRoot)
    }
}

# Validate workspace root looks like a project root (.git) or a VS Code multi-root workspace (*.code-workspace)
$wsHasGit       = Test-Path (Join-Path $WorkspaceRoot '.git')
$wsHasWorkspace = [bool](Get-ChildItem $WorkspaceRoot -Filter '*.code-workspace' -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $wsHasGit -and -not $wsHasWorkspace) {
    Write-Warning "Workspace root '$WorkspaceRoot' does not contain a .git directory or *.code-workspace file. Verify the path is correct."
}
$GithubDir  = Join-Path $WorkspaceRoot '.github'
$SkillsDir  = Join-Path $GithubDir 'skills'
$AgentsDir  = Join-Path $GithubDir 'agents'

# Determine whether speckit root is already inside .github/skills/speckit/
$ExpectedSpeckitDir = Join-Path $SkillsDir 'speckit'
$SpeckitIsExternal  = ($SpeckitRoot -ne (Resolve-Path $ExpectedSpeckitDir -ErrorAction SilentlyContinue))

# --- Self-update from GitHub release ------------------------------------------
if ($Update -and -not $Uninstall -and -not $IsBootstrap) {
    # Remove previously copied skill/agent directories before re-downloading
    $manifestPath = Join-Path $GithubDir 'speckit-manifest.json'
    if (Test-Path $manifestPath) {
        Write-Host 'Removing previous speckit copies...' -ForegroundColor Cyan
        $oldManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        foreach ($s in $oldManifest.skills) {
            $p = Join-Path $WorkspaceRoot $s.link
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force
                Write-Host "  [removed] $($s.link)" -ForegroundColor Yellow
            }
        }
        foreach ($a in $oldManifest.agents) {
            $p = Join-Path $WorkspaceRoot $a.link
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force
                Write-Host "  [removed] $($a.link)" -ForegroundColor Yellow
            }
        }
        Write-Host ''
    }

    Write-Host 'Downloading latest speckit release from GitHub...' -ForegroundColor Cyan
    $downloadedTag = Get-SpeckitFromGitHub -DestDir $SpeckitRoot
    Write-Host ''
}

# --- Definitions -------------------------------------------------------------
# Sub-skills: link into .github/skills/
$Skills = @(
    'speckit-specify'
    'speckit-research'
    'speckit-plan'
    'speckit-implement'
    'speckit-constitution'
    'speckit-verify'
)

# Agents: link into .github/agents/
$Agents = @(
    'speckit-codebase-scanner'
    'speckit-living-docs-loader'
    'speckit-e2e-browser'
    'speckit-e2e-api'
    'speckit-nexus'
    'speckit-pipeline-checker'
    'speckit-web-researcher'
    'speckit-test'
    'speckit-e2e'
    'speckit-retro'
)

# --- Helpers ------------------------------------------------------------------
function New-Link {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    if (Test-Path $LinkPath) {
        if ($script:ForceMode) {
            Write-Host "  [replace] Removing existing: $LinkPath" -ForegroundColor Yellow
            Remove-Item $LinkPath -Recurse -Force
        }
        else {
            Write-Host "  [skip] Already exists: $LinkPath" -ForegroundColor DarkGray
            return
        }
    }

    $isDir = (Test-Path $TargetPath -PathType Container)
    if ($isDir) {
        Copy-Item -Path $TargetPath -Destination $LinkPath -Recurse -Force
    }
    else {
        Copy-Item -Path $TargetPath -Destination $LinkPath -Force
    }
    Write-Host "  [copy] $LinkPath <- $TargetPath" -ForegroundColor Green
}

function Remove-Link {
    param([string]$LinkPath)

    if (-not (Test-Path $LinkPath -ErrorAction SilentlyContinue)) {
        Write-Host "  [skip] Not found: $LinkPath" -ForegroundColor DarkGray
        return
    }

    Remove-Item $LinkPath -Recurse -Force
    Write-Host "  [removed] $LinkPath" -ForegroundColor Yellow
}

# --- Main ---------------------------------------------------------------------
if (-not $IsBootstrap) {
    Write-Host ''
    Write-Host "Speckit Installer" -ForegroundColor Cyan
    Write-Host "  Workspace root : $WorkspaceRoot"
    Write-Host "  Speckit root   : $SpeckitRoot"
    Write-Host ''
}

if ($Uninstall) {
    Write-Host 'Removing speckit copies...' -ForegroundColor Yellow
    Write-Host ''

    $manifestPath = Join-Path $GithubDir 'speckit-manifest.json'
    if (Test-Path $manifestPath) {
        $oldManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        Write-Host 'Skills:' -ForegroundColor Cyan
        foreach ($s in $oldManifest.skills) {
            $p = Join-Path $WorkspaceRoot $s.link
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force
                Write-Host "  [removed] $($s.link)" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [skip] Not found: $($s.link)" -ForegroundColor DarkGray
            }
        }

        Write-Host ''
        Write-Host 'Agents:' -ForegroundColor Cyan
        foreach ($a in $oldManifest.agents) {
            $p = Join-Path $WorkspaceRoot $a.link
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force
                Write-Host "  [removed] $($a.link)" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [skip] Not found: $($a.link)" -ForegroundColor DarkGray
            }
        }

        Remove-Item $manifestPath -Force
        Write-Host ''
        Write-Host '  [removed] .github/speckit-manifest.json' -ForegroundColor Yellow
    }
    else {
        # No manifest -- fall back to hard-coded lists
        Write-Host 'Skills:' -ForegroundColor Cyan
        foreach ($skill in $Skills) {
            Remove-Link (Join-Path $SkillsDir $skill)
        }

        Write-Host ''
        Write-Host 'Agents:' -ForegroundColor Cyan
        foreach ($agent in $Agents) {
            Remove-Link (Join-Path $AgentsDir "$agent.agent.md")
        }
    }

    Write-Host ''
    Write-Host 'Done. Speckit copies removed.' -ForegroundColor Green
    return
}

# Install

# --- Stale detection: auto-update if expected files are missing ---------------
if (-not $Update -and -not $IsBootstrap) {
    $missingSources = @()
    foreach ($skill in $Skills) {
        $src = Join-Path (Join-Path $SpeckitRoot 'skills') $skill
        if (-not (Test-Path $src)) { $missingSources += "skill:$skill" }
    }
    foreach ($agent in $Agents) {
        $src = Join-Path (Join-Path $SpeckitRoot 'agents') "$agent.agent.md"
        if (-not (Test-Path $src)) { $missingSources += "agent:$agent" }
    }
    if ($missingSources.Count -gt 0) {
        Write-Host 'Stale speckit bundle detected — missing sources:' -ForegroundColor Yellow
        foreach ($m in $missingSources) { Write-Host "  $m" -ForegroundColor Yellow }
        Write-Host 'Auto-downloading latest release from GitHub...' -ForegroundColor Cyan
        $downloadedTag = Get-SpeckitFromGitHub -DestDir $SpeckitRoot
        # Force re-copy so stale destinations are replaced with fresh sources
        $script:ForceMode = $true
        Write-Host ''
    }
}

Write-Host 'Installing speckit copies...' -ForegroundColor Cyan
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
    $agentFile = "$agent.agent.md"
    $target = Join-Path (Join-Path $SpeckitRoot 'agents') $agentFile
    $link = Join-Path $AgentsDir $agentFile
    if (-not (Test-Path $target)) {
        Write-Warning "  [missing] Source not found: $target"
        continue
    }
    New-Link -LinkPath $link -TargetPath $target
}

# --- Git ignore the links and speckit root ------------------------------------
$gitignorePath = Join-Path $WorkspaceRoot '.gitignore'
$linksToIgnore = @('.github/skills/speckit')
foreach ($skill in $Skills) { $linksToIgnore += ".github/skills/$skill" }
foreach ($agent in $Agents) { $linksToIgnore += ".github/agents/$agent.agent.md" }

$existingIgnore = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { '' }
$newEntries = @()
foreach ($entry in $linksToIgnore) {
    if ($existingIgnore -notmatch [regex]::Escape($entry)) {
        $newEntries += $entry
    }
}

if ($newEntries.Count -gt 0) {
    Write-Host ''
    Write-Host 'Updating .gitignore with speckit entries...' -ForegroundColor Cyan
    $block = "`n# speckit copies (created by install.ps1)`n"
    $block += ($newEntries -join "`n") + "`n"
    Add-Content -Path $gitignorePath -Value $block -NoNewline
    Write-Host "  [updated] .gitignore - added $($newEntries.Count) entries" -ForegroundColor Green
}

# --- Write manifest -----------------------------------------------------------
$manifestPath = Join-Path $GithubDir 'speckit-manifest.json'

# Resolve commit hash at the speckit root (if it's a git repo or has .git info)
$speckitHash = $null
Push-Location $SpeckitRoot
try {
    $speckitHash = (git rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { $speckitHash = $null }
}
catch { $speckitHash = $null }
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
    $agentFile = "$agent.agent.md"
    $linkPath = Join-Path $AgentsDir $agentFile
    if (Test-Path $linkPath) {
        $linkedAgents += @{
            name   = $agent
            link   = ".github/agents/$agentFile"
            target = ".github/skills/speckit/agents/$agentFile"
        }
    }
}

$manifest = @{
    version            = 1
    installedAt        = (Get-Date -Format 'o')
    speckitHash        = $speckitHash
    speckitRootLinked  = $SpeckitIsExternal
    skills             = $linkedSkills
    agents             = $linkedAgents
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Host ''
Write-Host 'Manifest written to .github/speckit-manifest.json' -ForegroundColor Cyan
if ($speckitHash) {
    Write-Host "  Speckit hash: $speckitHash" -ForegroundColor DarkGray
}

# --- Keep bundle source sub-directories ----------------------------------------
# The skills/ and agents/ sub-directories inside the bundle are intentionally
# preserved so that:
#   1. Re-running install.ps1 is truly idempotent (sources are always available)
#   2. The Skill Resolution Protocol fallback paths work — sub-skills can
#      read_file from <speckit-root>/skills/{name}/SKILL.md when VS Code
#      discovery fails
#   3. -Update can re-copy cleanly without needing a GitHub download
# Both the bundle sources and the top-level copies are gitignored, so there
# is no repository bloat.

Write-Host ''
Write-Host 'Done. Speckit is installed.' -ForegroundColor Green
Write-Host ''
Write-Host 'The router skill (speckit) is at .github/skills/speckit/SKILL.md' -ForegroundColor DarkGray
Write-Host 'Sub-skills and agents are copied for VS Code discovery.' -ForegroundColor DarkGray
Write-Host ''
