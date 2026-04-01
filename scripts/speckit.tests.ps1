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

Describe 'speckit-research skill' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'SKILL.md exists' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        Test-Path $path | Should Be $true
    }

    It 'SKILL.md has user-invocable frontmatter' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'user-invocable:\s*true'
    }

    It 'SKILL.md references both subagents' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'speckit-codebase-scanner'
        $content | Should Match 'speckit-web-researcher'
    }

    It 'research-template.md exists' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\assets\research-template.md'
        Test-Path $path | Should Be $true
    }
}

Describe 'speckit-web-researcher agent' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'agent.md exists' {
        $path = Join-Path $speckitRoot 'agents\speckit-web-researcher.agent.md'
        Test-Path $path | Should Be $true
    }

    It 'agent.md has user-invocable false in frontmatter' {
        $path = Join-Path $speckitRoot 'agents\speckit-web-researcher.agent.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'user-invocable:\s*false'
    }

    It 'agent.md has structured evaluation criteria' {
        $path = Join-Path $speckitRoot 'agents\speckit-web-researcher.agent.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'Maintenance'
        $content | Should Match 'Popularity'
        $content | Should Match 'License'
    }
}

Describe 'install.ps1 registration' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
        $installContent = Get-Content (Join-Path $speckitRoot 'install.ps1') -Raw
    }

    It 'registers speckit-research in Skills array' {
        $installContent | Should Match "'speckit-research'"
    }

    It 'registers speckit-web-researcher in Agents array' {
        $installContent | Should Match "'speckit-web-researcher'"
    }
}

Describe 'pipeline wiring for research' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'root SKILL.md includes research in routing logic' {
        $content = Get-Content (Join-Path $speckitRoot 'SKILL.md') -Raw
        $content | Should Match 'speckit-research'
    }

    It 'specify Next Steps includes research option' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-specify\SKILL.md') -Raw
        $content | Should Match 'speckit-research'
    }

    It 'plan loads research.md via living-docs-loader' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-plan\SKILL.md') -Raw
        $content | Should Match 'docs/research\.md'
    }
}
