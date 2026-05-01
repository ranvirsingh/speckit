<#
.SYNOPSIS
    Verifies that markdown block markers (e.g. <!-- speckit-research:start -->)
    do not exceed a configurable line budget.

.DESCRIPTION
    Scans a file or string for speckit blocks and flags those that
    exceed the maximum allowed lines.

.PARAMETER FilePath
    The markdown file to scan.

.PARAMETER Text
    The markdown text to scan.

.PARAMETER MaxLines
    The maximum allowed lines for a block. Default is 500.

.EXAMPLE
    .\verify-marker-budget.ps1 -FilePath "issue.md" -MaxLines 500
#>

param(
    [string]$FilePath,
    [string]$Text,
    [int]$MaxLines = 500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $FilePath -and -not $Text) {
    Write-Error "Provide either -FilePath or -Text."
    exit 1
}

$content = ""
if ($FilePath) {
    if (Test-Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
    }
} else {
    $content = $Text
}

if (-not $content) {
    $content = ""
}

$lines = $content -split "`r?`n"

$inBlock = $false
$currentBlockPhase = ""
$currentBlockLines = 0
$blockStartLine = 0

$violations = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    
    if ($line -match "<!--\s*speckit-(.+?):start\s*-->") {
        $inBlock = $true
        $currentBlockPhase = $Matches[1]
        $currentBlockLines = 0
        $blockStartLine = $i + 1
        continue
    }
    
    if ($line -match "<!--\s*speckit-(.+?):end\s*-->") {
        if ($inBlock -and $currentBlockPhase -eq $Matches[1]) {
            if ($currentBlockLines -gt $MaxLines) {
                $violations += [PSCustomObject]@{
                    Phase = $currentBlockPhase
                    Lines = $currentBlockLines
                    MaxLines = $MaxLines
                    StartLine = $blockStartLine
                }
            }
        }
        $inBlock = $false
        continue
    }
    
    if ($inBlock) {
        $currentBlockLines++
    }
}

$result = [PSCustomObject]@{
    valid = ($violations.Count -eq 0)
    violations = @($violations)
}

$result | ConvertTo-Json -Depth 5
