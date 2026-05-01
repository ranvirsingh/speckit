<#
.SYNOPSIS
    Freezes the allowed edit paths for a speckit implementation.

.DESCRIPTION
    Reads the issue scope and writes .specify/frozen-edit-paths.json. The
    before_pr guard uses that file to block changes outside the declared scope.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Get-Location),
    [string]$IssueBody,
    [string[]]$AllowedPath = @(),
    [switch]$AllowEmpty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedPath {
    param([string]$Path)

    $normalized = $Path.Trim().Trim('`').Trim('"').Trim("'") -replace '\\', '/'
    $normalized = $normalized.TrimStart('./')
    if ($normalized -match '(^|/)\.\.(/|$)' -or [System.IO.Path]::IsPathRooted($normalized)) {
        throw "Path '$Path' must be a workspace-relative path."
    }
    return $normalized.TrimEnd('/')
}

function Get-ScopePathFromIssueBody {
    param([string]$Body)

    if (-not $Body) { return @() }

    $paths = New-Object System.Collections.Generic.List[string]
    $inScope = $false

    foreach ($line in ($Body -split "`r?`n")) {
        if ($line -match '^#{2,6}\s+(Scope|Affected Files|Files|Implementation Scope)\s*$') {
            $inScope = $true
            continue
        }
        if ($inScope -and $line -match '^#{2,6}\s+') { break }
        if (-not $inScope) { continue }

        foreach ($match in [regex]::Matches($line, '`([^`]+)`')) {
            $candidate = $match.Groups[1].Value
            if ($candidate -match '[./\\]' -or $candidate -match '\.[A-Za-z0-9]+$') {
                $paths.Add($candidate)
            }
        }

        if ($line -match '^\s*[-*]\s+([A-Za-z0-9_.\-/\\]+)\s*$') {
            $candidate = $Matches[1]
            if ($candidate -match '[./\\]' -or $candidate -match '\.[A-Za-z0-9]+$') {
                $paths.Add($candidate)
            }
        }
    }

    return $paths.ToArray()
}

$workspace = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$scopePaths = @()
$scopePaths += $AllowedPath
$scopePaths += Get-ScopePathFromIssueBody -Body $IssueBody

$normalizedPaths = @(
    $scopePaths |
        Where-Object { $_ -and $_.Trim() } |
        ForEach-Object { ConvertTo-NormalizedPath -Path $_ } |
        Sort-Object -Unique
)

if ($normalizedPaths.Count -eq 0 -and -not $AllowEmpty) {
    throw 'No allowed edit paths were found. Add scoped paths to the issue body or pass -AllowedPath.'
}

$specifyDir = Join-Path $workspace '.specify'
if (-not (Test-Path -LiteralPath $specifyDir)) {
    New-Item -ItemType Directory -Path $specifyDir -Force | Out-Null
}

$freezePath = Join-Path $specifyDir 'frozen-edit-paths.json'
$payload = [ordered]@{
    schemaVersion = 1
    createdAt     = (Get-Date -Format 'o')
    allowedPaths  = $normalizedPaths
}

$payload | ConvertTo-Json -Depth 4 | Set-Content -Path $freezePath -Encoding UTF8
Write-Output "Frozen edit paths written to .specify/frozen-edit-paths.json"
foreach ($path in $normalizedPaths) {
    Write-Output "  - $path"
}
