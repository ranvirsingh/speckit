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

    It 'SKILL.md references the web-researcher subagent' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'speckit-web-researcher'
    }

    It 'RESEARCH.TEMPLATE.md exists' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\assets\RESEARCH.TEMPLATE.md'
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

Describe 'speckit-test agent' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'agent.md exists' {
        $path = Join-Path $speckitRoot 'agents\speckit-test.agent.md'
        Test-Path $path | Should Be $true
    }

    It 'agent.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-test.agent.md') -Raw
        $content | Should Match 'name:\s*speckit-test'
    }

    It 'old speckit-test skill directory is removed' {
        $path = Join-Path $speckitRoot 'skills\speckit-test'
        Test-Path $path | Should Be $false
    }
}

Describe 'speckit-e2e agent' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'agent.md exists' {
        $path = Join-Path $speckitRoot 'agents\speckit-e2e.agent.md'
        Test-Path $path | Should Be $true
    }

    It 'agent.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-e2e.agent.md') -Raw
        $content | Should Match 'name:\s*speckit-e2e'
    }

    It 'old speckit-e2e skill directory is removed' {
        $path = Join-Path $speckitRoot 'skills\speckit-e2e'
        Test-Path $path | Should Be $false
    }
}

Describe 'speckit-e2e-browser agent' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'agent.md exists' {
        $path = Join-Path $speckitRoot 'agents\speckit-e2e-browser.agent.md'
        Test-Path $path | Should Be $true
    }

    It 'agent.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-e2e-browser.agent.md') -Raw
        $content | Should Match 'name:\s*speckit-e2e-browser'
    }

    It 'old e2e-recorder agent is removed' {
        $path = Join-Path $speckitRoot 'agents\speckit-e2e-recorder.agent.md'
        Test-Path $path | Should Be $false
    }
}

Describe 'speckit-e2e-api agent' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'agent.md exists' {
        $path = Join-Path $speckitRoot 'agents\speckit-e2e-api.agent.md'
        Test-Path $path | Should Be $true
    }

    It 'agent.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-e2e-api.agent.md') -Raw
        $content | Should Match 'name:\s*speckit-e2e-api'
    }
}

Describe 'install.ps1 agent registration' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
        $installContent = Get-Content (Join-Path $speckitRoot 'install.ps1') -Raw
    }

    It 'registers speckit-test in Agents array' {
        $installContent | Should Match "'speckit-test'"
    }

    It 'registers speckit-e2e in Agents array' {
        $installContent | Should Match "'speckit-e2e'"
    }

    It 'registers speckit-e2e-browser in Agents array' {
        $installContent | Should Match "'speckit-e2e-browser'"
    }

    It 'registers speckit-e2e-api in Agents array' {
        $installContent | Should Match "'speckit-e2e-api'"
    }

    It 'registers speckit-web-researcher in Agents array' {
        $installContent | Should Match "'speckit-web-researcher'"
    }

    It 'RETRO.TEMPLATE.md still exists in agents/assets (used by speckit-implement at done-done)' {
        $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'agents\assets\RETRO.TEMPLATE.md'
        Test-Path $path | Should Be $true
    }

    It 'PARKING-LOT.TEMPLATE.md still exists in agents/assets (used by speckit-implement at done-done)' {
        $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'agents\assets\PARKING-LOT.TEMPLATE.md'
        Test-Path $path | Should Be $true
    }

    It 'deprecated retro/doctor/loader/scanner/nexus/pipeline-checker agents are removed' {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
        foreach ($name in 'speckit-retro','speckit-living-docs-loader','speckit-codebase-scanner','speckit-nexus','speckit-pipeline-checker') {
            (Test-Path (Join-Path $speckitRoot "agents\$name.agent.md")) | Should Be $false
        }
        (Test-Path (Join-Path $speckitRoot 'skills\speckit-doctor')) | Should Be $false
    }

    It 'does NOT register speckit-e2e-recorder in Agents array' {
        $installContent | Should Not Match "'speckit-e2e-recorder'"
    }

    It 'does NOT register speckit-test in Skills array' {
        # speckit-test was moved to agents; should not appear in Skills
        $installContent -replace '\$Agents[\s\S]*', '' | Should Not Match "'speckit-test'"
    }
}

Describe 'handoff schema' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'HANDOFF-SCHEMA.md exists' {
        $path = Join-Path $speckitRoot 'references\HANDOFF-SCHEMA.md'
        Test-Path $path | Should Be $true
    }

    It 'AGENT-PROTOCOL.md references circuit breaker' {
        $content = Get-Content (Join-Path $speckitRoot 'references\AGENT-PROTOCOL.md') -Raw
        $content | Should Match 'Circuit Breaker'
    }

    It 'router SKILL.md references PipelineContext' {
        $content = Get-Content (Join-Path $speckitRoot 'SKILL.md') -Raw
        $content | Should Match 'PipelineContext'
    }

    It 'router SKILL.md references runSubagent for test' {
        $content = Get-Content (Join-Path $speckitRoot 'SKILL.md') -Raw
        $content | Should Match 'runSubagent.*speckit-test'
    }
}

Describe 'PipelineContext schema (#22) extensions' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
        $schemaPath  = Join-Path $speckitRoot 'references\HANDOFF-SCHEMA.md'
        $schema      = Get-Content $schemaPath -Raw
    }

    It 'documents artifactIndex with all five required fixed keys' {
        $schema | Should Match 'artifactIndex'
        foreach ($key in 'researchCommentId','planCommentId','dataModelPath','openapiPath','e2eEvidenceDir') {
            $schema | Should Match $key
        }
    }

    It 'documents artifactIndex.extra with schemaVersion and entries' {
        $schema | Should Match 'extra'
        $schema | Should Match 'schemaVersion'
        $schema | Should Match 'entries'
    }

    It 'documents contextBudget.maxSourceLines with default 1500 and advisory wording' {
        $schema | Should Match 'contextBudget'
        $schema | Should Match 'maxSourceLines'
        $schema | Should Match '1500'
        $schema | Should Match 'advisory'
    }

    It 'documents contextBudget.loadedArtifacts as an audit trail' {
        $schema | Should Match 'loadedArtifacts'
    }

    It 'documents phaseVerdicts with pass, fail, blocked enum values' {
        $schema | Should Match 'phaseVerdicts'
        $schema | Should Match '"pass"'
        $schema | Should Match '"fail"'
        $schema | Should Match '"blocked"'
    }

    It 'documents the /memories/repo/ write convention with the five required fields' {
        $schema | Should Match '/memories/repo/'
        foreach ($field in 'subject','fact','citations','reason','category') {
            $schema | Should Match $field
        }
    }

    It 'states all new fields are optional / backward compatible' {
        $schema | Should Match 'optional'
        $schema | Should Match 'backward'
    }

    It 'AGENT-PROTOCOL.md cross-references the /memories/repo/ convention' {
        $protocol = Get-Content (Join-Path $speckitRoot 'references\AGENT-PROTOCOL.md') -Raw
        $protocol | Should Match '/memories/repo/'
        $protocol | Should Match 'Cross-Phase Memory'
    }

    It 'speckit-research SKILL.md notes which PipelineContext fields it writes' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-research\SKILL.md') -Raw
        $content | Should Match 'researchCommentId'
        $content | Should Match 'phaseVerdicts.research'
    }

    It 'speckit-plan SKILL.md notes which PipelineContext fields it writes' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-plan\SKILL.md') -Raw
        $content | Should Match 'planCommentId'
        $content | Should Match 'phaseVerdicts.plan'
    }

    It 'speckit-implement SKILL.md notes phaseVerdicts.implement' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-implement\SKILL.md') -Raw
        $content | Should Match 'phaseVerdicts'
        $content | Should Match 'implement'
    }

    It 'speckit-verify SKILL.md notes the new PipelineContext checks' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-verify\SKILL.md') -Raw
        $content | Should Match 'maxSourceLines'
        $content | Should Match 'phaseVerdicts'
    }

    It 'speckit-test agent notes phaseVerdicts.test' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-test.agent.md') -Raw
        $content | Should Match 'phaseVerdicts.test'
    }

    It 'speckit-e2e agent notes phaseVerdicts.e2e and e2eEvidenceDir' {
        $content = Get-Content (Join-Path $speckitRoot 'agents\speckit-e2e.agent.md') -Raw
        $content | Should Match 'phaseVerdicts.e2e'
        $content | Should Match 'e2eEvidenceDir'
    }
}

