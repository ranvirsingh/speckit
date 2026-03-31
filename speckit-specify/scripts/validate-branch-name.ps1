<#
.SYNOPSIS
    Validates a branch name against the speckit naming convention.
.DESCRIPTION
    Enforces the pattern: NNN-lowercase-kebab-name (e.g., "003-add-auth-flow").
    Rules:
      - Starts with a 3-digit zero-padded number
      - Followed by a hyphen
      - Followed by 2-4 lowercase kebab-case words (a-z, 0-9, hyphens)
      - No uppercase, no underscores, no trailing hyphens
    Also checks uniqueness against existing local and remote branches.
.OUTPUTS
    Exits 0 with "VALID" on success. Exits 1 with error message on failure.
.EXAMPLE
    .\validate-branch-name.ps1 -Name "003-add-auth-flow"
    # Output: VALID
.EXAMPLE
    .\validate-branch-name.ps1 -Name "3-Fix_Login"
    # Output: INVALID: Branch name "3-Fix_Login" does not match pattern ...
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

$ErrorActionPreference = "Stop"

# Pattern: 3 digits, hyphen, then 2-4 kebab-case words (each 2+ chars)
$pattern = '^\d{3}-[a-z][a-z0-9]*(-[a-z][a-z0-9]*){1,3}$'

if ($Name -notmatch $pattern) {
    Write-Output "INVALID: Branch name `"$Name`" does not match pattern NNN-lowercase-kebab (2-4 words). Example: 003-add-auth-flow"
    exit 1
}

# Check uniqueness against existing branches
try {
    $branches = git branch -a 2>$null
    if ($branches) {
        foreach ($branch in $branches) {
            $cleaned = $branch.Trim().TrimStart("* ")
            # Strip remote prefix for comparison
            $cleaned = $cleaned -replace '^remotes/[^/]+/', ''
            if ($cleaned -eq $Name) {
                Write-Output "INVALID: Branch `"$Name`" already exists."
                exit 1
            }
        }
    }
}
catch {
    Write-Warning "Could not check branch uniqueness: $_"
}

Write-Output "VALID"
exit 0
