<#
.SYNOPSIS
    Pester tests for speckit PowerShell scripts.

.DESCRIPTION
    Run with: Invoke-Pester -Path scripts/speckit.tests.ps1
#>

Describe 'check-constitution.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'check-constitution.ps1'
    }

    It 'returns exists=false when no constitution file' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $result = & $scriptPath -WorkspaceRoot $tempDir | ConvertFrom-Json
            $result.exists | Should Be $false
            $result.valid | Should Be $false
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'returns valid=false when constitution has template placeholders' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-test-$(Get-Random)"
        $docsDir = Join-Path $tempDir 'docs'
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        Set-Content (Join-Path $docsDir 'constitution.md') '# Constitution for [PROJECT_NAME]'
        try {
            $result = & $scriptPath -WorkspaceRoot $tempDir | ConvertFrom-Json
            $result.exists | Should Be $true
            $result.valid | Should Be $false
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'returns valid=true when constitution is complete with principles' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-test-$(Get-Random)"
        $docsDir = Join-Path $tempDir 'docs'
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        $content = @"
# Constitution for MyProject

## Principle 1: Quality First

All code MUST have tests.

## Principle 2: Documentation

All APIs MUST be documented.
"@
        Set-Content (Join-Path $docsDir 'constitution.md') $content
        try {
            $result = & $scriptPath -WorkspaceRoot $tempDir | ConvertFrom-Json
            $result.exists | Should Be $true
            $result.valid | Should Be $true
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'returns valid=false when no principle sections exist' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-test-$(Get-Random)"
        $docsDir = Join-Path $tempDir 'docs'
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        Set-Content (Join-Path $docsDir 'constitution.md') '# Constitution for MyProject'
        try {
            $result = & $scriptPath -WorkspaceRoot $tempDir | ConvertFrom-Json
            $result.exists | Should Be $true
            $result.valid | Should Be $false
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

Describe 'validate-commit-msg.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\skills\speckit-implement\scripts\validate-commit-msg.ps1'
    }

    It 'accepts valid conventional commit' {
        $result = & $scriptPath -Message "feat(auth): add login endpoint`n`nCloses #42"
        $result | Should Be 'VALID'
    }

    It 'rejects invalid commit message' {
        $result = & $scriptPath -Message 'did some stuff'
        $result | Should Match 'INVALID'
    }
}

Describe 'validate-branch-name.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\skills\speckit-specify\scripts\validate-branch-name.ps1'
    }

    It 'accepts valid branch name' {
        $result = & $scriptPath -Name '001-add-login'
        $result | Should Be 'VALID'
    }
}
