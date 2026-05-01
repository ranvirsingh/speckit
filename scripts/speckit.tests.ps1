<#
.SYNOPSIS
    Pester tests for speckit PowerShell scripts.

.DESCRIPTION
    Run with: Invoke-Pester -Path scripts/speckit.tests.ps1
#>

$script:SpeckitTestRoot = Join-Path (Split-Path $PSScriptRoot -Parent) '.tmp'
if (-not (Test-Path $script:SpeckitTestRoot)) {
    New-Item -ItemType Directory -Path $script:SpeckitTestRoot -Force | Out-Null
}
$env:TEMP = $script:SpeckitTestRoot
$env:TMP = $script:SpeckitTestRoot

function New-SpeckitTestDirectory {
    $root = $script:SpeckitTestRoot
    $tempDir = Join-Path $root "speckit-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    return $tempDir
}

Describe 'check-constitution.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'check-constitution.ps1'
    }

    It 'returns exists=false when no constitution file' {
        $tempDir = New-SpeckitTestDirectory
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
        $tempDir = New-SpeckitTestDirectory
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
        $tempDir = New-SpeckitTestDirectory
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
        $tempDir = New-SpeckitTestDirectory
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

Describe 'speckit-research skill ownership' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'research skill owns web research instructions' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        Test-Path $path | Should Be $true
        $content = Get-Content $path -Raw
        $content | Should Match 'web-researcher'
    }

    It 'research skill has structured research dimensions' {
        $path = Join-Path $speckitRoot 'skills\speckit-research\SKILL.md'
        $content = Get-Content $path -Raw
        $content | Should Match 'Technology choices'
        $content | Should Match 'Architecture patterns'
        $content | Should Match 'Security implications'
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

    It 'does not use the legacy Agents array' {
        $installContent | Should Not Match '\$Agents\s*='
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

Describe 'speckit-test skill' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'SKILL.md exists' {
        $path = Join-Path $speckitRoot 'skills\speckit-test\SKILL.md'
        Test-Path $path | Should Be $true
    }

    It 'SKILL.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-test\SKILL.md') -Raw
        $content | Should Match 'name:\s*speckit-test'
    }

    It 'is user invocable' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-test\SKILL.md') -Raw
        $content | Should Match 'user-invocable:\s*true'
    }
}

Describe 'speckit-e2e skill' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
    }

    It 'SKILL.md exists' {
        $path = Join-Path $speckitRoot 'skills\speckit-e2e\SKILL.md'
        Test-Path $path | Should Be $true
    }

    It 'SKILL.md has correct name in frontmatter' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-e2e\SKILL.md') -Raw
        $content | Should Match 'name:\s*speckit-e2e'
    }

    It 'is user invocable' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-e2e\SKILL.md') -Raw
        $content | Should Match 'user-invocable:\s*true'
    }
}

Describe 'speckit-e2e browser/API guidance' {
    BeforeAll {
        $speckitRoot = Split-Path $PSScriptRoot -Parent
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-e2e\SKILL.md') -Raw
    }

    It 'documents browser e2e generation' {
        $content | Should Match 'Playwright'
        $content | Should Match 'browser'
    }

    It 'documents API e2e generation' {
        $content | Should Match 'API'
        $content | Should Match 'request'
    }
}

Describe 'install.ps1 skill registration' {
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

    It 'RETRO.TEMPLATE.md exists in implement assets (used at done-done)' {
        $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'skills\speckit-implement\assets\RETRO.TEMPLATE.md'
        Test-Path $path | Should Be $true
    }

    It 'PARKING-LOT.TEMPLATE.md exists in implement assets (used at done-done)' {
        $path = Join-Path (Split-Path $PSScriptRoot -Parent) 'skills\speckit-implement\assets\PARKING-LOT.TEMPLATE.md'
        Test-Path $path | Should Be $true
    }

    It 'deprecated doctor skill is removed' {
        (Test-Path (Join-Path $speckitRoot 'skills\speckit-doctor')) | Should Be $false
    }

    It 'does NOT register speckit-e2e-recorder' {
        $installContent | Should Not Match "'speckit-e2e-recorder'"
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

    It 'router SKILL.md routes to the test skill' {
        $content = Get-Content (Join-Path $speckitRoot 'SKILL.md') -Raw
        $content | Should Match 'route to `speckit-test`'
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

    It 'speckit-test skill notes phaseVerdicts.test' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-test\SKILL.md') -Raw
        $content | Should Match 'phaseVerdicts.test'
    }

    It 'speckit-e2e skill notes phaseVerdicts.e2e and e2eEvidenceDir' {
        $content = Get-Content (Join-Path $speckitRoot 'skills\speckit-e2e\SKILL.md') -Raw
        $content | Should Match 'phaseVerdicts.e2e'
        $content | Should Match 'e2eEvidenceDir'
    }
}

Describe 'verify-marker-budget.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'verify-marker-budget.ps1'
    }

    It 'returns valid=true when no blocks exist' {
        $result = & $scriptPath -Text "Hello world" | ConvertFrom-Json
        $result.valid | Should Be $true
    }

    It 'returns valid=true when block is under budget' {
        $text = "<!-- speckit-research:start -->`nline1`nline2`n<!-- speckit-research:end -->"
        $result = & $scriptPath -Text $text -MaxLines 5 | ConvertFrom-Json
        $result.valid | Should Be $true
        $result.violations.Count | Should Be 0
    }

    It 'returns valid=false when block is over budget' {
        $text = "<!-- speckit-plan:start -->`nline1`nline2`nline3`n<!-- speckit-plan:end -->"
        $result = & $scriptPath -Text $text -MaxLines 2 | ConvertFrom-Json
        $result.valid | Should Be $false
        $result.violations[0].Phase | Should Be 'plan'
        $result.violations[0].Lines | Should Be 3
    }
}

Describe 'before_implement guard (#25)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'invoke-before-implement-guard.ps1'
    }

    It 'freezes scoped paths from issue body' {
        $tempDir = New-SpeckitTestDirectory
        $body = @(
            '## Scope'
            ''
            '- `scripts/invoke-before-pr-guard.ps1`'
            '- `references/HOOKS.md`'
        ) -join "`n"
        try {
            & $scriptPath -WorkspaceRoot $tempDir -IssueBody $body | Out-Null
            $freeze = Get-Content (Join-Path $tempDir '.specify\frozen-edit-paths.json') -Raw | ConvertFrom-Json
            (@($freeze.allowedPaths) -contains 'scripts/invoke-before-pr-guard.ps1') | Should Be $true
            (@($freeze.allowedPaths) -contains 'references/HOOKS.md') | Should Be $true
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'rejects an empty scope by default' {
        $tempDir = New-SpeckitTestDirectory
        try {
            { & $scriptPath -WorkspaceRoot $tempDir -IssueBody '## Scope' } | Should Throw
        }
        finally {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

Describe 'before_pr guard (#25)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'invoke-before-pr-guard.ps1'
    }

    It 'passes when current changes stay inside frozen edit paths' {
        $tempDir = New-SpeckitTestDirectory
        try {
            Push-Location $tempDir
            git init -b main | Out-Null
            git config user.email test@example.com
            git config user.name 'Speckit Test'
            New-Item -ItemType Directory -Path 'scripts','.specify' -Force | Out-Null
            Set-Content scripts\guard.ps1 'base'
            git add -A
            git commit -m 'chore: seed' | Out-Null
            git checkout -b feature | Out-Null
            $freeze = @{ schemaVersion = 1; allowedPaths = @('scripts') } | ConvertTo-Json
            Set-Content .specify\frozen-edit-paths.json $freeze
            Set-Content scripts\guard.ps1 'changed'
            git add scripts\guard.ps1
            git commit -m 'chore: change guard' | Out-Null

            $result = & $scriptPath -WorkspaceRoot $tempDir -BaseRef main
            $result | Should Match 'passed'
        }
        finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'fails when current changes leave frozen edit paths' {
        $tempDir = New-SpeckitTestDirectory
        try {
            Push-Location $tempDir
            git init -b main | Out-Null
            git config user.email test@example.com
            git config user.name 'Speckit Test'
            New-Item -ItemType Directory -Path 'scripts','.specify' -Force | Out-Null
            Set-Content scripts\guard.ps1 'base'
            git add -A
            git commit -m 'chore: seed' | Out-Null
            git checkout -b feature | Out-Null
            $freeze = @{ schemaVersion = 1; allowedPaths = @('scripts') } | ConvertTo-Json
            Set-Content .specify\frozen-edit-paths.json $freeze
            Set-Content README.md 'outside'
            git add README.md
            git commit -m 'chore: change outside scope' | Out-Null

            { & $scriptPath -WorkspaceRoot $tempDir -BaseRef main } | Should Throw
        }
        finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force
        }
    }

    It 'fails on introduced TODO(speckit) markers by default' {
        $tempDir = New-SpeckitTestDirectory
        try {
            Push-Location $tempDir
            git init -b main | Out-Null
            git config user.email test@example.com
            git config user.name 'Speckit Test'
            New-Item -ItemType Directory -Path 'scripts','.specify' -Force | Out-Null
            Set-Content scripts\guard.ps1 'base'
            git add -A
            git commit -m 'chore: seed' | Out-Null
            git checkout -b feature | Out-Null
            $freeze = @{ schemaVersion = 1; allowedPaths = @('scripts') } | ConvertTo-Json
            Set-Content .specify\frozen-edit-paths.json $freeze
            Set-Content scripts\guard.ps1 '# TODO(speckit): triage this'
            git add scripts\guard.ps1
            git commit -m 'chore: add todo' | Out-Null

            { & $scriptPath -WorkspaceRoot $tempDir -BaseRef main } | Should Throw
        }
        finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

