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
    # Check for known template placeholders from CONSTITUTION.TEMPLATE.md
    $templatePlaceholders = @(
        '\[PROJECT_NAME\]'
        '\[PRINCIPLE_\d+_NAME\]'
        '\[PRINCIPLE_\d+_DESCRIPTION\]'
        '\[SECTION_\d+_NAME\]'
        '\[SECTION_\d+_CONTENT\]'
        '\[GOVERNANCE_RULES\]'
        '\[CONSTITUTION_VERSION\]'
        '\[RATIFICATION_DATE\]'
        '\[LAST_AMENDED_DATE\]'
        '\[GUIDANCE_FILE\]'
    )
    $pattern = ($templatePlaceholders -join '|')
    $placeholderCount = ([regex]::Matches($content, $pattern)).Count
    # Check for at least one principle section (heading like "## Principle" or "### Principle")
    $principleCount = ([regex]::Matches($content, '(?mi)^#{2,3}\s+Principle')).Count
    $valid = $placeholderCount -eq 0 -and $principleCount -gt 0
}

$result = @{
    exists = $exists
    valid  = $valid
    path   = 'docs/constitution.md'
}

$result | ConvertTo-Json -Compress
