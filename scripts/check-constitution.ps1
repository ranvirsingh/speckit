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

$result = @{
    exists = $exists
    path   = 'docs/constitution.md'
}

$result | ConvertTo-Json -Compress
