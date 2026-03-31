<#
.SYNOPSIS
    Validates a commit message against Conventional Commits format with issue reference.
.DESCRIPTION
    Enforces:
      - Type: feat|fix|chore|docs|refactor|test|ci|style|perf|build
      - Optional scope in parentheses (lowercase, no spaces)
      - Subject: imperative mood, lowercase start, max 72 chars, no period
      - Footer must contain "Closes #N" or "Fixes #N"
    Reads from stdin or -Message parameter.
.OUTPUTS
    Exits 0 with "VALID" on success. Exits 1 with specific error on failure.
.EXAMPLE
    .\validate-commit-msg.ps1 -Message "feat(auth): add login flow`n`nCloses #3"
    # Output: VALID
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

$lines = $Message -split "`n"
$subject = $lines[0].Trim()

# --- Validate subject line ---
$subjectPattern = '^(feat|fix|chore|docs|refactor|test|ci|style|perf|build)(\([a-z0-9-]+\))?: [a-z].{0,69}[^.]$'

if ($subject -notmatch $subjectPattern) {
    # Diagnose specific issues
    if ($subject -notmatch '^(feat|fix|chore|docs|refactor|test|ci|style|perf|build)') {
        Write-Output "INVALID: Subject must start with a valid type (feat|fix|chore|docs|refactor|test|ci|style|perf|build)."
        exit 1
    }
    if ($subject -match '\)\s*:' -or $subject -match '\(\s') {
        Write-Output "INVALID: No spaces inside or around scope parentheses. Use: type(scope): subject"
        exit 1
    }
    if ($subject.Length -gt 72) {
        Write-Output "INVALID: Subject line exceeds 72 characters ($($subject.Length) chars)."
        exit 1
    }
    if ($subject -match '\.$') {
        Write-Output "INVALID: Subject must not end with a period."
        exit 1
    }
    if ($subject -match '^[a-z]+(\([a-z0-9-]+\))?: [A-Z]') {
        Write-Output "INVALID: Subject description must start with lowercase."
        exit 1
    }
    Write-Output "INVALID: Subject line does not match conventional commit format. Expected: type(scope): lowercase subject"
    exit 1
}

# --- Validate issue reference in footer ---
$fullMessage = $Message
if ($fullMessage -notmatch '(Closes|Fixes)\s+#\d+') {
    Write-Output "INVALID: Commit must contain 'Closes #N' or 'Fixes #N' referencing the GitHub issue."
    exit 1
}

Write-Output "VALID"
exit 0
