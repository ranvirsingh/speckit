<#
.SYNOPSIS
    Sets the Issue State field on a GitHub Project item.

.DESCRIPTION
    Finds an issue in a GitHub Project and sets its "Issue State" field
    to the specified speckit pipeline state. Used by speckit pipeline skills
    to advance issues through the board automatically.

.PARAMETER ProjectNumber
    The GitHub Project number (e.g. 17).

.PARAMETER Owner
    The GitHub user or org that owns the project. Defaults to "@me".

.PARAMETER IssueUrl
    The full URL of the issue (e.g. https://github.com/owner/repo/issues/42).

.PARAMETER IssueNumber
    The issue number within the repo. Used with -Repo instead of -IssueUrl.

.PARAMETER Repo
    The owner/repo slug (e.g. ranvirsingh/typetime). Used with -IssueNumber.

.PARAMETER State
    The pipeline state to set. Must be one of:
    Parking Lot, Backlog, Specify, Research, Plan, Implement, Test, E2E, Retro, Done

.PARAMETER FieldName
    The name of the state field. Defaults to "Issue State".

.PARAMETER DefaultState
    The default state to set when auto-adding an issue to the project for the first time.
    Defaults to "Parking Lot". Set to empty string to skip default state assignment.

.EXAMPLE
    .\set-issue-state.ps1 -ProjectNumber 17 -Owner ranvirsingh -IssueNumber 5 -Repo ranvirsingh/typetime -State "Implement"
    .\set-issue-state.ps1 -ProjectNumber 17 -Owner ranvirsingh -IssueUrl "https://github.com/ranvirsingh/typetime/issues/5" -State "Specify"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int]$ProjectNumber,

    [string]$Owner = "@me",

    [string]$IssueUrl,

    [int]$IssueNumber,

    [string]$Repo,

    [Parameter(Mandatory)]
    [ValidateSet("Parking Lot", "Backlog", "Specify", "Research", "Plan", "Implement", "Test", "E2E", "Retro", "Done")]
    [string]$State,

    [string]$FieldName = "Issue State",

    [string]$DefaultState = "Parking Lot"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Validate input ----
if (-not $IssueUrl -and (-not $IssueNumber -or -not $Repo)) {
    Write-Error "Provide either -IssueUrl or both -IssueNumber and -Repo."
    exit 1
}

# -- Resolve owner ----
$resolvedOwner = $Owner
if ($Owner -eq "@me") {
    $resolvedOwner = (gh api user --jq '.login') 2>&1
}

# -- Step 1: Get the field ID and option ID ----
Write-Host "Finding field '$FieldName' option '$State'..." -ForegroundColor Yellow

$fields = gh project field-list $ProjectNumber --owner $Owner --format json 2>&1 | ConvertFrom-Json
$field = $fields.fields | Where-Object { $_.name -eq $FieldName }

if (-not $field) {
    Write-Error "Field '$FieldName' not found on project #$ProjectNumber. Run setup-project-board.ps1 first."
    exit 1
}

$fieldId = $field.id
$option = $field.options | Where-Object { $_.name -eq $State }

if (-not $option) {
    Write-Error "Option '$State' not found on field '$FieldName'. Available: $($field.options.name -join ', ')"
    exit 1
}

$optionId = $option.id
Write-Host "  Field: $fieldId | Option '$State': $optionId" -ForegroundColor White

# -- Step 2: Find the issue's node ID ----
Write-Host "Resolving issue node ID..." -ForegroundColor Yellow

if ($IssueUrl) {
    # Extract owner/repo/number from URL
    if ($IssueUrl -match 'github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
        $Repo = "$($Matches[1])/$($Matches[2])"
        $IssueNumber = [int]$Matches[3]
    } else {
        Write-Error "Could not parse issue URL: $IssueUrl"
        exit 1
    }
}

$repoOwner = $Repo.Split("/")[0]
$repoName = $Repo.Split("/")[1]

$issueQuery = 'query { repository(owner: \"' + $repoOwner + '\", name: \"' + $repoName + '\") { issue(number: ' + $IssueNumber + ') { id title } } }'

$issueData = (gh api graphql -f query="$issueQuery" --jq '.data.repository.issue') 2>&1 | ConvertFrom-Json
$issueNodeId = $issueData.id

Write-Host "  Issue #${IssueNumber}: $($issueData.title)" -ForegroundColor White

# -- Step 3: Find the project item ID for this issue ----
Write-Host "Finding project item..." -ForegroundColor Yellow

$projectQuery = 'query { user(login: \"' + $resolvedOwner + '\") { projectV2(number: ' + $ProjectNumber + ') { id items(first: 100) { nodes { id content { ... on Issue { id number } } } } } } }'

$projectData = (gh api graphql -f query="$projectQuery" --jq '.data.user.projectV2') 2>&1 | ConvertFrom-Json
$projectId = $projectData.id

$projectItem = $projectData.items.nodes | Where-Object { $_.content.id -eq $issueNodeId }

if (-not $projectItem) {
    Write-Host "  Issue not in project - adding it now..." -ForegroundColor DarkYellow
    $addResult = gh project item-add $ProjectNumber --owner $Owner --url "https://github.com/$Repo/issues/$IssueNumber" --format json 2>&1 | ConvertFrom-Json
    $itemId = $addResult.id
    Write-Host "  [done] Added to project (item id: $itemId)" -ForegroundColor Green

    # Set default state on newly added items
    if ($DefaultState -and $DefaultState -ne $State) {
        $defaultOption = $field.options | Where-Object { $_.name -eq $DefaultState }
        if ($defaultOption) {
            Write-Host "  Setting default state '$DefaultState' first..." -ForegroundColor White
            $defaultMutation = 'mutation { updateProjectV2ItemFieldValue(input: { projectId: \"' + $projectId + '\", itemId: \"' + $itemId + '\", fieldId: \"' + $fieldId + '\", value: { singleSelectOptionId: \"' + $defaultOption.id + '\" } }) { projectV2Item { id } } }'
            gh api graphql -f query="$defaultMutation" --silent 2>&1 | Out-Null
        }
    }
} else {
    $itemId = $projectItem.id
    Write-Host "  Found item: $itemId" -ForegroundColor White
}

# -- Step 4: Set the field value ----
Write-Host "Setting '$FieldName' -> '$State'..." -ForegroundColor Yellow

$setMutation = 'mutation { updateProjectV2ItemFieldValue(input: { projectId: \"' + $projectId + '\", itemId: \"' + $itemId + '\", fieldId: \"' + $fieldId + '\", value: { singleSelectOptionId: \"' + $optionId + '\" } }) { projectV2Item { id } } }'

gh api graphql -f query="$setMutation" --silent 2>&1 | Out-Null

Write-Host "[done] Issue #${IssueNumber} -> '$State'" -ForegroundColor Green
Write-Host ""

# Return structured output
[PSCustomObject]@{
    ProjectNumber = $ProjectNumber
    IssueNumber   = $IssueNumber
    Repo          = $Repo
    State         = $State
    ItemId        = $itemId
    FieldId       = $fieldId
    OptionId      = $optionId
}
