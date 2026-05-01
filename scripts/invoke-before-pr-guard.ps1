<#
.SYNOPSIS
    Runs speckit before_pr guard checks.

.DESCRIPTION
    Blocks destructive changes, changes outside frozen edit paths, and
    untriaged TODO(speckit) markers introduced by the current branch.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Get-Location),
    [string]$BaseRef = 'main',
    [string]$FrozenPathsFile,
    [switch]$AllowDestructive,
    [switch]$AllowUntriagedTodo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedPath {
    param([string]$Path)
    return (($Path.Trim() -replace '\\', '/').TrimStart('./')).TrimEnd('/')
}

function Test-IsPathAllowed {
    param(
        [string]$ChangedPath,
        [string[]]$AllowedPaths
    )

    $changed = ConvertTo-NormalizedPath -Path $ChangedPath
    foreach ($allowed in $AllowedPaths) {
        $scope = ConvertTo-NormalizedPath -Path $allowed
        if ($changed -eq $scope -or $changed.StartsWith("$scope/")) {
            return $true
        }
    }
    return $false
}

$workspace = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
Push-Location $workspace
try {
    git rev-parse --is-inside-work-tree | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'WorkspaceRoot is not inside a git worktree.' }

    $mergeBase = (git merge-base $BaseRef HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $mergeBase) {
        $mergeBase = $BaseRef
    }

    $nameStatus = @(git diff --name-status $mergeBase HEAD)
    $diffText = (git diff --unified=0 $mergeBase HEAD)

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    $destructive = @(
        $nameStatus |
            Where-Object { $_ -match '^(D|R\d{0,3})\s+' }
    )
    if ($destructive.Count -gt 0 -and -not $AllowDestructive) {
        $errors.Add("Destructive changes detected:`n  - $($destructive -join "`n  - ")")
    }

    if (-not $FrozenPathsFile) {
        $FrozenPathsFile = Join-Path $workspace '.specify/frozen-edit-paths.json'
    }

    if (Test-Path -LiteralPath $FrozenPathsFile) {
        $frozen = Get-Content -LiteralPath $FrozenPathsFile -Raw | ConvertFrom-Json
        $allowedPaths = @($frozen.allowedPaths)
        if ($allowedPaths.Count -gt 0) {
            foreach ($line in $nameStatus) {
                $parts = $line -split "`t"
                $changedPath = if ($parts.Count -ge 3 -and $parts[0] -match '^R') { $parts[2] } else { $parts[-1] }
                if (-not (Test-IsPathAllowed -ChangedPath $changedPath -AllowedPaths $allowedPaths)) {
                    $errors.Add("Change outside frozen edit paths: $changedPath")
                }
            }
        }
    }
    else {
        $warnings.Add('No frozen edit path file found at .specify/frozen-edit-paths.json.')
    }

    $introducedTodos = @(
        $diffText -split "`r?`n" |
            Where-Object { $_ -match '^\+\s*(#|//|/\*|\*)\s*TODO\(speckit\)' }
    )
    if ($introducedTodos.Count -gt 0) {
        $todoSummary = "Introduced TODO(speckit) markers:`n  - $($introducedTodos -join "`n  - ")"
        if ($AllowUntriagedTodo) {
            $warnings.Add($todoSummary)
        }
        else {
            $errors.Add("$todoSummary`nTriage them into an issue or docs/PARKING_LOT.md before marking the PR ready.")
        }
    }

    foreach ($warning in $warnings) {
        Write-Warning $warning
    }

    if ($errors.Count -gt 0) {
        throw "before_pr guard failed:`n- $($errors -join "`n- ")"
    }

    Write-Output 'before_pr guard passed.'
}
finally {
    Pop-Location
}
