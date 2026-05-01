<#
.SYNOPSIS
    Returns deterministic phase-state JSON for a given issue.

.DESCRIPTION
    Scrapes the local git repository and the GitHub issue to produce
    a JSON structure describing the current state of the pipeline
    (issue info, branch, PR, checklist status, phase markers).

    This script is designed to be consumed by an external agent harness
    so it can deterministically decide which skill to invoke next.

.PARAMETER IssueNumber
    The GitHub Issue number to inspect.

.EXAMPLE
    .\get-pipeline-state.ps1 -IssueNumber 26
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------- 1. Fetch Issue JSON ------------------------------------------------
$issueOutput = gh issue view $IssueNumber --json number,title,state,body,comments 2>$null
if (-not $issueOutput) {
    Write-Error "Could not fetch issue #$IssueNumber. Are you authenticated with gh cli?"
    exit 1
}
$issueJson = $issueOutput | ConvertFrom-Json

# ---------- 2. Find branch & last commit --------------------------------------
$branch     = git branch --show-current 2>$null
$lastCommit = git rev-parse HEAD 2>$null

# ---------- 3. Find PR for current branch (may not exist) ---------------------
$prObj = $null
$ErrorActionPreference = "SilentlyContinue"
$prRaw = gh pr view --json number,url 2>$null
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -eq 0 -and $prRaw) {
    $prData = $prRaw | ConvertFrom-Json
    $prObj = @{
        number = $prData.number
        url    = $prData.url
    }
}

# ---------- 4. Extract phase markers from body + comments ---------------------
$markers = @()
$allText = if ($issueJson.body) { $issueJson.body } else { "" }
if ($issueJson.comments) {
    foreach ($c in $issueJson.comments) {
        $allText += "`n" + $c.body
    }
}

$phaseMatches = [regex]::Matches($allText, "<!--\s*speckit-(.+?):start\s*-->")
foreach ($m in $phaseMatches) {
    $markers += $m.Groups[1].Value
}
$markers = @($markers | Select-Object -Unique)

# ---------- 5. Derive current phase from markers ------------------------------
# Phase precedence (last wins): specify < research < plan < implement < test < e2e
$phaseOrder = @('specify','research','plan','implement','test','e2e')
$currentPhase = $null
foreach ($p in $phaseOrder) {
    if ($markers -contains $p) { $currentPhase = $p }
}

# ---------- 6. Calculate checklist status --------------------------------------
$total     = 0
$completed = 0
if ($issueJson.body) {
    $taskMatches = [regex]::Matches($issueJson.body, "(?m)^[-*]\s+\[([ xX])\]")
    foreach ($tm in $taskMatches) {
        $total++
        if ($tm.Groups[1].Value -match "[xX]") {
            $completed++
        }
    }
}

# ---------- 7. Output JSON ----------------------------------------------------
$result = [PSCustomObject]@{
    issueNumber     = $issueJson.number
    title           = $issueJson.title
    state           = $issueJson.state
    branch          = $branch
    pr              = $prObj
    currentPhase    = $currentPhase
    checklistStatus = [PSCustomObject]@{
        total     = $total
        completed = $completed
    }
    phaseMarkers    = $markers
    lastCommit      = $lastCommit
}

$result | ConvertTo-Json -Depth 5
