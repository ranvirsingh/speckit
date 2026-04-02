<#
.SYNOPSIS
    Installs speckit skills and subagents into the standard VS Code discovery paths.

.DESCRIPTION
    Creates directory junctions (Windows) or symlinks (macOS/Linux) from speckit
    sub-skill and subagent directories into .github/skills/ and .github/agents/
    so VS Code discovers them without manual settings.json configuration.

    Usage from any project root:
      irm https://raw.githubusercontent.com/ranvirsingh/speckit/main/install.ps1 | iex

    Or if already installed:
      pwsh .github/skills/speckit/install.ps1

    The script is idempotent -- safe to run multiple times.

.PARAMETER Uninstall
    Remove all speckit links from .github/skills/ and .github/agents/.

.PARAMETER Force
    Replace existing real directories with junctions. Without this flag,
    the script skips directories that exist but are not links.

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

# Detect bootstrap mode: running from piped input (irm | iex) or no valid speckit root
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
    Write-Host "Downloading latest speckit release from GitHub..." -ForegroundColor Cyan
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
    'speckit-web-researcher'
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
        $isTargetFile = (Test-Path $TargetPath -PathType Leaf)
        $isWinFileCopy = ($env:OS -eq 'Windows_NT') -and $isTargetFile -and -not $item.PSIsContainer -and -not $isLink
        if ($isLink) {
            Write-Host "  [skip] Already linked: $LinkPath" -ForegroundColor DarkGray
            return
        }
        elseif ($isWinFileCopy -and -not $script:ForceMode) {
            # On Windows, files are copied not linked -- check content hash
            $srcHash = (Get-FileHash $TargetPath -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash $LinkPath -Algorithm SHA256).Hash
            if ($srcHash -eq $dstHash) {
                Write-Host "  [skip] Already copied: $LinkPath" -ForegroundColor DarkGray
                return
            }
            else {
                # Content differs -- overwrite
                Copy-Item -Path $TargetPath -Destination $LinkPath -Force
                Write-Host "  [update] $LinkPath <- $TargetPath" -ForegroundColor Green
                return
            }
        }
        elseif ($script:ForceMode) {
            Write-Host "  [replace] Removing existing: $LinkPath" -ForegroundColor Yellow
            Remove-Item $LinkPath -Recurse -Force
        }
        else {
            Write-Warning "  [conflict] $LinkPath exists but is not a link. Use -Force to replace."
            return
        }
    }

    $isDir = (Test-Path $TargetPath -PathType Container)
    $isWin = ($env:OS -eq 'Windows_NT')
    if ($isWin -and $isDir) {
        # Directory junction -- no admin rights needed on Windows
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
        Write-Host "  [link] $LinkPath -> $TargetPath" -ForegroundColor Green
    }
    elseif ($isWin -and -not $isDir) {
        # File symlinks need admin on Windows -- copy instead
        Copy-Item -Path $TargetPath -Destination $LinkPath -Force
        Write-Host "  [copy] $LinkPath <- $TargetPath" -ForegroundColor Green
    }
    else {
        # Symlink for files and directories on macOS/Linux
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
        Write-Host "  [link] $LinkPath -> $TargetPath" -ForegroundColor Green
    }
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
if (-not $IsBootstrap) {
    Write-Host ''
    Write-Host "Speckit Installer" -ForegroundColor Cyan
    Write-Host "  Workspace root : $WorkspaceRoot"
    Write-Host "  Speckit root   : $SpeckitRoot"
    Write-Host ''
}

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
        Remove-Link (Join-Path $AgentsDir "$agent.agent.md")
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
    Write-Host "Updating .gitignore with speckit links..." -ForegroundColor Cyan
    $block = "`n# speckit links (created by install.ps1)`n"
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
Write-Host "Manifest written to .github/speckit-manifest.json" -ForegroundColor Cyan
if ($speckitHash) {
    Write-Host "  Speckit hash: $speckitHash" -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "Done. Speckit is installed." -ForegroundColor Green
Write-Host ''
Write-Host "The router skill (speckit) is at .github/skills/speckit/SKILL.md" -ForegroundColor DarkGray
Write-Host "Sub-skills and agents are linked for VS Code discovery." -ForegroundColor DarkGray
Write-Host ''
