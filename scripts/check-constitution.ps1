<#
.SYNOPSIS
    Checks whether a project constitution exists at docs/constitution.md.

.DESCRIPTION
    Returns a JSON object indicating whether the constitution file exists
    and its path. Used by the speckit router to gate pipeline entry.

.PARAMETER WorkspaceRoot
    The workspace root directory. Defaults to the current directory.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Get-Location)
)

Set-StrictMode -Version Latest

$constitutionPath = Join-Path (Join-Path $WorkspaceRoot 'docs') 'constitution.md'
$exists = Test-Path $constitutionPath
$valid = $false

if ($exists) {
    $content = Get-Content $constitutionPath -Raw
    # A constitution with placeholder tokens still present is not valid
    $placeholderCount = ([regex]::Matches($content, '\[([A-Z][A-Z0-9_]+)\]')).Count
    $valid = $placeholderCount -eq 0
}

$result = @{
    exists = $exists
    valid  = $valid
    path   = 'docs/constitution.md'
}

$result | ConvertTo-Json -Compress
