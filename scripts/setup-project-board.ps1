<#
.SYNOPSIS
    Sets up a GitHub Project board with speckit pipeline columns (issue_state field)
    and creates a board view grouped by that field.

.DESCRIPTION
    Creates a SINGLE_SELECT field called "Issue State" on a GitHub Project
    with options mapping to speckit pipeline phases:
      Parking Lot > Backlog > Specify > Research > Plan > Implement > Test > E2E > Retro > Done

    Then creates a board view via GraphQL with the new field as column source.

.PARAMETER ProjectNumber
    The GitHub Project number (e.g. 17).

.PARAMETER Owner
    The GitHub user or org that owns the project. Defaults to "@me".

.PARAMETER FieldName
    The name for the pipeline state field. Defaults to "Issue State".

.PARAMETER ViewName
    The name for the new board view. Defaults to "Pipeline Board".

.PARAMETER DryRun
    If set, prints what would be done without making changes.

.EXAMPLE
    .\setup-project-board.ps1 -ProjectNumber 17 -Owner ranvirsingh
    .\setup-project-board.ps1 -ProjectNumber 17 -Owner ranvirsingh -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int]$ProjectNumber,

    [string]$Owner = "@me",

    [string]$FieldName = "Issue State",

    [string]$ViewName = "Pipeline Board",

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Speckit pipeline states in order
$PipelineStates = @(
    "Parking Lot",
    "Backlog",
    "Specify",
    "Research",
    "Plan",
    "Implement",
    "Test",
    "E2E",
    "Retro",
    "Done"
)

$statesCsv = ($PipelineStates -join ",")

Write-Host ""
Write-Host "=== Speckit Project Board Setup ===" -ForegroundColor Cyan
Write-Host "  Project:  #$ProjectNumber"
Write-Host "  Owner:    $Owner"
Write-Host "  Field:    $FieldName"
Write-Host "  States:   $statesCsv"
Write-Host "  View:     $ViewName"
Write-Host ""

# -- Step 1: Check if field already exists ----
Write-Host "[1/4] Checking existing fields..." -ForegroundColor Yellow

$existingFields = gh project field-list $ProjectNumber --owner $Owner --format json 2>&1 | ConvertFrom-Json

$existingField = $existingFields.fields | Where-Object { $_.name -eq $FieldName }

if ($existingField) {
    Write-Host "  [skip] Field '$FieldName' already exists (id: $($existingField.id))" -ForegroundColor Green
    $fieldId = $existingField.id
} else {
    if ($DryRun) {
        Write-Host "  [dry-run] Would create field '$FieldName' with options: $statesCsv" -ForegroundColor Magenta
        $fieldId = "DRY_RUN_FIELD_ID"
    } else {
        Write-Host "  Creating field '$FieldName'..." -ForegroundColor White

        $result = gh project field-create $ProjectNumber `
            --owner $Owner `
            --name $FieldName `
            --data-type "SINGLE_SELECT" `
            --single-select-options $statesCsv `
            --format json 2>&1 | ConvertFrom-Json

        $fieldId = $result.id
        Write-Host "  [done] Created field '$FieldName' (id: $fieldId)" -ForegroundColor Green
    }
}

# -- Early exit for dry-run ----
if ($DryRun) {
    Write-Host "[2/4] [dry-run] Would resolve project node ID via GraphQL" -ForegroundColor Magenta
    Write-Host "[3/4] [dry-run] Would create board view '$ViewName'" -ForegroundColor Magenta
    Write-Host "[4/4] [dry-run] Would set '$FieldName' as column field on '$ViewName'" -ForegroundColor Magenta
    $viewId = "DRY_RUN_VIEW_ID"

    Write-Host ""
    Write-Host "=== Dry Run Complete ===" -ForegroundColor Cyan
    Write-Host "  No changes were made." -ForegroundColor White
    Write-Host ""
    return [PSCustomObject]@{
        ProjectNumber = $ProjectNumber
        Owner         = $Owner
        FieldName     = $FieldName
        FieldId       = $fieldId
        ViewName      = $ViewName
        ViewId        = $viewId
        States        = $PipelineStates
    }
}

# -- Step 2: Get project node ID for GraphQL ----
Write-Host "[2/4] Resolving project node ID..." -ForegroundColor Yellow

$resolvedOwner = $Owner
if ($Owner -eq "@me") {
    $resolvedOwner = (gh api user --jq '.login') 2>&1
}

$projectQuery = 'query { user(login: \"' + $resolvedOwner + '\") { projectV2(number: ' + $ProjectNumber + ') { id views(first: 20) { nodes { id name layout } } } } }'

$projectData = (gh api graphql -f query="$projectQuery" --jq '.data.user.projectV2') 2>&1 | ConvertFrom-Json
$projectId = $projectData.id

Write-Host "  Project node ID: $projectId" -ForegroundColor White

# -- Step 3: Find or instruct view creation ----
# Note: GitHub GraphQL API does not support createProjectV2View.
# Views must be created via the web UI. If the view already exists, we can
# detect it. Otherwise we print instructions.
Write-Host "[3/4] Checking existing views..." -ForegroundColor Yellow

$existingView = $projectData.views.nodes | Where-Object { $_.name -eq $ViewName }

if ($existingView) {
    Write-Host "  [skip] View '$ViewName' already exists (id: $($existingView.id))" -ForegroundColor Green
    $viewId = $existingView.id
} else {
    Write-Host "  [action required] GitHub API does not support creating views programmatically." -ForegroundColor DarkYellow
    Write-Host "  To create the '$ViewName' view:" -ForegroundColor White
    Write-Host "    1. Open: gh project view $ProjectNumber --owner $Owner --web" -ForegroundColor White
    Write-Host "    2. Click '+' next to existing views to add a new Board view" -ForegroundColor White
    Write-Host "    3. Name it '$ViewName'" -ForegroundColor White
    Write-Host "    4. Click the view dropdown > 'Column field' > '$FieldName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  After creating the view, re-run this script to auto-detect it." -ForegroundColor White
    $viewId = $null
}

# -- Step 4: Configure view column field (if view exists) ----
if ($viewId) {
    Write-Host "[4/4] Configuring view column field..." -ForegroundColor Yellow

    $configMutation = 'mutation { updateProjectV2View(input: { viewId: \"' + $viewId + '\", verticalGroupByFieldId: \"' + $fieldId + '\" }) { projectV2View { id name } } }'

    $configError = $null
    try {
        gh api graphql -f query="$configMutation" 2>&1 | Out-Null
    } catch {
        $configError = $_
    }

    if ($configError) {
        Write-Host "  [warn] Could not auto-configure column field via GraphQL." -ForegroundColor DarkYellow
        Write-Host "         Set it manually: view dropdown > Column field > '$FieldName'" -ForegroundColor DarkYellow
    } else {
        Write-Host "  [done] Configured '$FieldName' as column field on '$ViewName'" -ForegroundColor Green
    }
} else {
    Write-Host "[4/4] [skip] No view to configure - create the view in GitHub UI first." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "  Field ID: $fieldId"
Write-Host "  View ID:  $viewId"
Write-Host ""
$openCmd = "gh project view $ProjectNumber --owner $Owner --web"
Write-Host "  Open in browser: $openCmd" -ForegroundColor White
Write-Host ""

# Return structured output for piping
[PSCustomObject]@{
    ProjectNumber = $ProjectNumber
    Owner         = $Owner
    FieldName     = $FieldName
    FieldId       = $fieldId
    ViewName      = $ViewName
    ViewId        = $viewId
    States        = $PipelineStates
}
