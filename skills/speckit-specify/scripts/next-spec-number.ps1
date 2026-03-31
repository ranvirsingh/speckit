<#
.SYNOPSIS
    Returns the next available spec number by scanning git branches and GitHub labels.
.DESCRIPTION
    Scans all local and remote git branches plus GitHub issue labels for the pattern
    "NNN" (3-digit zero-padded number). Returns the next available number.
    This is the single source of truth for spec numbering — the LLM must not derive
    spec numbers manually.
.OUTPUTS
    A single line: the next spec number, zero-padded to 3 digits (e.g., "004").
.EXAMPLE
    .\next-spec-number.ps1
    # Output: 004
.EXAMPLE
    .\next-spec-number.ps1 -RepoFlag "owner/repo"
    # Also scans GitHub labels for spec:NNN patterns
#>

param(
    [string]$RepoFlag = ""
)

$ErrorActionPreference = "Stop"

$maxNumber = 0

# --- Scan git branches ---
try {
    $branches = git branch -a 2>$null
    if ($branches) {
        foreach ($branch in $branches) {
            $branch = $branch.Trim().TrimStart("* ")
            # Match branch names starting with NNN- (e.g., "003-feature-name", "remotes/origin/003-feature-name")
            if ($branch -match '(?:^|/)(\d{3})-') {
                $num = [int]$Matches[1]
                if ($num -gt $maxNumber) { $maxNumber = $num }
            }
        }
    }
}
catch {
    Write-Error "Failed to scan git branches: $_"
    exit 1
}

# --- Scan GitHub labels (if repo provided) ---
if ($RepoFlag -ne "") {
    try {
        $labels = gh label list --repo $RepoFlag --json name --jq ".[].name" 2>$null
        if ($labels) {
            foreach ($label in $labels) {
                # Match labels like "spec:003"
                if ($label -match '^spec:(\d{3})$') {
                    $num = [int]$Matches[1]
                    if ($num -gt $maxNumber) { $maxNumber = $num }
                }
            }
        }
    }
    catch {
        # Non-fatal — labels are supplementary
        Write-Warning "Could not scan GitHub labels: $_"
    }
}

# --- Scan GitHub issues (if repo provided) ---
if ($RepoFlag -ne "") {
    try {
        $issues = gh issue list --repo $RepoFlag --state all --json title --jq ".[].title" --limit 200 2>$null
        if ($issues) {
            foreach ($title in $issues) {
                # Match issue titles like "[Feature] 003 — ..." or "[Bug] 012 — ..."
                if ($title -match '^\[(?:Feature|Bug|Chore)\]\s+(\d{3})\s') {
                    $num = [int]$Matches[1]
                    if ($num -gt $maxNumber) { $maxNumber = $num }
                }
            }
        }
    }
    catch {
        Write-Warning "Could not scan GitHub issues: $_"
    }
}

$next = $maxNumber + 1
$padded = $next.ToString("D3")

Write-Output $padded
