<#
.SYNOPSIS
    Extracts MUST, SHOULD, and NON-NEGOTIABLE rules from docs/constitution.md.

.DESCRIPTION
    Parses the constitution file and returns a JSON array of rules with their
    severity (must, should, non-negotiable), source principle, and text.
    Used by the speckit-verify skill to check compliance.

.PARAMETER WorkspaceRoot
    The workspace root directory. Defaults to the current directory.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Get-Location)
)

Set-StrictMode -Version Latest

$constitutionPath = Join-Path (Join-Path $WorkspaceRoot 'docs') 'constitution.md'

if (-not (Test-Path $constitutionPath)) {
    @{ exists = $false; rules = @(); path = 'docs/constitution.md' } | ConvertTo-Json -Depth 3
    return
}

$content = Get-Content $constitutionPath -Raw
$lines = Get-Content $constitutionPath

$rules = @()
$currentPrinciple = ''

foreach ($line in $lines) {
    # Track current principle heading
    if ($line -match '^###\s+(.+)') {
        $currentPrinciple = $Matches[1].Trim()
        continue
    }
    if ($line -match '^##\s+(.+)') {
        $currentPrinciple = $Matches[1].Trim()
        continue
    }

    # Extract NON-NEGOTIABLE markers (highest severity)
    if ($line -match 'NON-NEGOTIABLE') {
        $rules += @{
            severity  = 'non-negotiable'
            principle = $currentPrinciple
            text      = $line.Trim().TrimStart('-', ' ', '*')
        }
        continue
    }

    # Extract MUST rules (stronger than SHOULD — takes precedence if both present)
    if ($line -match '\bMUST\b') {
        $rules += @{
            severity  = 'must'
            principle = $currentPrinciple
            text      = $line.Trim().TrimStart('-', ' ', '*')
        }
        continue
    }

    # Extract SHOULD rules
    if ($line -match '\bSHOULD\b') {
        $rules += @{
            severity  = 'should'
            principle = $currentPrinciple
            text      = $line.Trim().TrimStart('-', ' ', '*')
        }
    }
}

@{
    exists = $true
    path   = 'docs/constitution.md'
    total  = $rules.Count
    rules  = $rules
} | ConvertTo-Json -Depth 3
