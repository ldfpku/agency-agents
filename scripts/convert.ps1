<#
.SYNOPSIS
Convert agency agent .md files into tool-specific formats.

.DESCRIPTION
Reads all agent files from the standard category directories and outputs
converted files to integrations/<tool>/. Run this to regenerate all
integration files after adding or modifying agents.

.PARAMETER Tool
Target tool to convert formats for (antigravity, gemini-cli, opencode, cursor, aider, windsurf, openclaw, qwen, all).

.PARAMETER OutDir
Output directory path. Defaults to integrations/ relative to repo root.

.PARAMETER Parallel
Included for compatibility with the bash script arguments (Executes sequentially in this PowerShell version).

.PARAMETER Jobs
Included for compatibility.
#>

param (
    [string]$Tool = "all",
    [string]$OutDir = "",
    [switch]$Parallel,
    [int]$Jobs = 4
)

$ErrorActionPreference = "Stop"

# --- Constants & Paths ---
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$REPO_ROOT = Split-Path -Parent $SCRIPT_DIR

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $REPO_ROOT "integrations"
}

$TODAY = Get-Date -Format "yyyy-MM-dd"

$AGENT_DIRS = @(
    "academic", "design", "engineering", "game-development", "marketing", "paid-media", "sales", "product", "project-management",
    "testing", "support", "spatial-computing", "specialized"
)

# --- UI Helpers ---
function Write-Info($Msg) { Write-Host "[OK]  $Msg" -ForegroundColor Green }
function Write-Warn($Msg) { Write-Host "[!!]  $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg($Msg) { Write-Host "[ERR] $Msg" -ForegroundColor Red }
function Write-Header($Msg) { Write-Host "`n$Msg" -ForegroundColor Cyan }

# --- Utility Functions ---
function Get-Slug([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return "" }
    $slug = $Name.ToLower() -replace '[^a-z0-9]', '-' -replace '-+', '-'
    return $slug.Trim('-')
}

function Parse-AgentFile([string]$FilePath) {
    $lines = Get-Content $FilePath
    if ($lines.Count -eq 0 -or $lines[0] -ne "---") { return $null }

    $fm = @{}
    $i = 1
    while ($i -lt $lines.Count -and $lines[$i] -ne "---") {
        $line = $lines[$i]
        if ($line -match "^([^:]+):\s*(.*)$") {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            if ($val -match "^'(.*)'$") { $val = $matches[1] }
            elseif ($val -match "^`"(.*)`"$") { $val = $matches[1] }
            $fm[$key] = $val
        }
        $i++
    }

    if ($i -ge $lines.Count) { return $null }

    $bodyLines = $lines[($i+1)..($lines.Count-1)]
    $body = $bodyLines -join "`r`n"

    return @{
        Frontmatter = $fm
        Body = $body
    }
}

function Resolve-OpenCodeColor([string]$Color) {
    $c = $Color.Trim().ToLower()
    switch ($c) {
        "cyan" { return "#00FFFF" }
        "blue" { return "#3498DB" }
        "green" { return "#2ECC71" }
        "red" { return "#E74C3C" }
        "purple" { return "#9B59B6" }
        "orange" { return "#F39C12" }
        "teal" { return "#008080" }
        "indigo" { return "#6366F1" }
        "pink" { return "#E84393" }
        "gold" { return "#EAB308" }
        "amber" { return "#F59E0B" }
        "neon-green" { return "#10B981" }
        "neon-cyan" { return "#06B6D4" }
        "metallic-blue" { return "#3B82F6" }
        "yellow" { return "#EAB308" }
        "violet" { return "#8B5CF6" }
        "rose" { return "#F43F5E" }
        "lime" { return "#84CC16" }
        "gray" { return "#6B7280" }
        "fuchsia" { return "#D946EF" }
        default {
            if ($c -match "^#[0-9a-f]{6}$") { return $c.ToUpper() }
            if ($c -match "^[0-9a-f]{6}$") { return "#$c".ToUpper() }
            return "#6B7280"
        }
    }
}

# --- Converters ---
function Convert-Antigravity($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $slug = "agency-" + (Get-Slug $name)
    $body = $Parsed.Body

    $outDir = Join-Path (Join-Path $Out "antigravity") $slug
    $outFile = Join-Path $outDir "SKILL.md"
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $content = @"
---
name: $slug
description: $desc
risk: low
source: community
date_added: '$TODAY'
---
$body
"@
    Set-Content -Path $outFile -Value $content -Encoding UTF8
}

function Convert-GeminiCli($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $slug = Get-Slug $name
    $body = $Parsed.Body

    $outDir = Join-Path (Join-Path (Join-Path $Out "gemini-cli") "skills") $slug
    $outFile = Join-Path $outDir "SKILL.md"
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $content = @"
---
name: $slug
description: $desc
---
$body
"@
    Set-Content -Path $outFile -Value $content -Encoding UTF8
}

function Convert-OpenCode($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $color = Resolve-OpenCodeColor $Parsed.Frontmatter["color"]
    $slug = Get-Slug $name
    $body = $Parsed.Body

    $outDir = Join-Path (Join-Path $Out "opencode") "agents"
    $outFile = Join-Path $outDir "$slug.md"
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $content = @"
---
name: $name
description: $desc
mode: subagent
color: '$color'
---
$body
"@
    Set-Content -Path $outFile -Value $content -Encoding UTF8
}

function Convert-Cursor($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $slug = Get-Slug $name
    $body = $Parsed.Body

    $outDir = Join-Path (Join-Path $Out "cursor") "rules"
    $outFile = Join-Path $outDir "$slug.mdc"
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $content = @"
---
description: $desc
globs: ""
alwaysApply: false
---
$body
"@
    Set-Content -Path $outFile -Value $content -Encoding UTF8
}

function Convert-OpenClaw($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $slug = Get-Slug $name

    $outDir = Join-Path (Join-Path $Out "openclaw") $slug
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $soulContent = [System.Text.StringBuilder]::new()
    $agentsContent = [System.Text.StringBuilder]::new()
    $currentTarget = "agents"
    $currentSection = [System.Text.StringBuilder]::new()

    foreach ($line in ($Parsed.Body -split "`r`n|`n")) {
        if ($line -match "^##\s") {
            if ($currentSection.Length -gt 0) {
                if ($currentTarget -eq "soul") { [void]$soulContent.AppendLine($currentSection.ToString()) }
                else { [void]$agentsContent.AppendLine($currentSection.ToString()) }
            }
            $currentSection.Clear()

            $headerLower = $line.ToLower()
            if ($headerLower -match "identity|communication|style|critical rule|rules you must follow") {
                $currentTarget = "soul"
            } else {
                $currentTarget = "agents"
            }
        }
        [void]$currentSection.AppendLine($line)
    }
    
    if ($currentSection.Length -gt 0) {
        if ($currentTarget -eq "soul") { [void]$soulContent.AppendLine($currentSection.ToString()) }
        else { [void]$agentsContent.AppendLine($currentSection.ToString()) }
    }

    Set-Content -Path (Join-Path $outDir "SOUL.md") -Value $soulContent.ToString() -Encoding UTF8
    Set-Content -Path (Join-Path $outDir "AGENTS.md") -Value $agentsContent.ToString() -Encoding UTF8

    $emoji = $Parsed.Frontmatter["emoji"]
    $vibe = $Parsed.Frontmatter["vibe"]
    if (-not [string]::IsNullOrWhiteSpace($emoji) -and -not [string]::IsNullOrWhiteSpace($vibe)) {
        Set-Content -Path (Join-Path $outDir "IDENTITY.md") -Value "# $emoji $name`n$vibe" -Encoding UTF8
    } else {
        Set-Content -Path (Join-Path $outDir "IDENTITY.md") -Value "# $name`n$desc" -Encoding UTF8
    }
}

function Convert-Qwen($Parsed, $Out) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $tools = $Parsed.Frontmatter["tools"]
    $slug = Get-Slug $name
    $body = $Parsed.Body

    $outDir = Join-Path (Join-Path $Out "qwen") "agents"
    $outFile = Join-Path $outDir "$slug.md"
    $null = New-Item -ItemType Directory -Force -Path $outDir

    $frontmatter = "---`nname: $slug`ndescription: $desc"
    if (-not [string]::IsNullOrWhiteSpace($tools)) {
        $frontmatter += "`ntools: $tools"
    }
    $frontmatter += "`n---"

    Set-Content -Path $outFile -Value "$frontmatter`n$body" -Encoding UTF8
}

# --- Accumulators ---
$global:AiderContent = [System.Text.StringBuilder]::new()
[void]$global:AiderContent.AppendLine("# The Agency — AI Agent Conventions`n#`n# This file provides Aider with the full roster of specialized AI agents from`n# The Agency (https://github.com/msitarzewski/agency-agents).`n#`n# To activate an agent, reference it by name in your Aider session prompt, e.g.:`n#   `"Use the Frontend Developer agent to review this component.`"`n#`n# Generated by scripts/convert.ps1 — do not edit manually.`n")

$global:WindsurfContent = [System.Text.StringBuilder]::new()
[void]$global:WindsurfContent.AppendLine("# The Agency — AI Agent Rules for Windsurf`n#`n# Full roster of specialized AI agents from The Agency.`n# To activate an agent, reference it by name in your Windsurf conversation.`n#`n# Generated by scripts/convert.ps1 — do not edit manually.`n")

function Accumulate-Aider($Parsed) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $body = $Parsed.Body
    [void]$global:AiderContent.AppendLine("---`n`n## $name`n`n> $desc`n`n$body`n")
}

function Accumulate-Windsurf($Parsed) {
    $name = $Parsed.Frontmatter["name"]
    $desc = $Parsed.Frontmatter["description"]
    $body = $Parsed.Body
    [void]$global:WindsurfContent.AppendLine("================================================================================`n## $name`n$desc`n================================================================================`n`n$body`n")
}

# --- Main ---
$validTools = @("antigravity", "gemini-cli", "opencode", "cursor", "aider", "windsurf", "openclaw", "qwen", "all")
if ($Tool -notin $validTools) {
    Write-ErrorMsg "Unknown tool '$Tool'. Valid: $($validTools -join ', ')"
    exit 1
}

Write-Header "The Agency -- Converting agents to tool-specific formats"
Write-Host "  Repo:   $REPO_ROOT"
Write-Host "  Output: $OutDir"
Write-Host "  Tool:   $Tool"
Write-Host "  Date:   $TODAY"

$toolsToRun = if ($Tool -eq "all") { $validTools | Where-Object { $_ -ne "all" } } else { @($Tool) }
$total = 0

foreach ($t in $toolsToRun) {
    Write-Header "`nConverting: $t"
    $count = 0

    foreach ($dir in $AGENT_DIRS) {
        $dirPath = Join-Path $REPO_ROOT $dir
        if (-not (Test-Path $dirPath)) { continue }

        $files = Get-ChildItem -Path $dirPath -Filter "*.md" -File
        foreach ($file in $files) {
            $parsed = Parse-AgentFile $file.FullName
            if ($null -eq $parsed -or [string]::IsNullOrWhiteSpace($parsed.Frontmatter["name"])) { continue }

            switch ($t) {
                "antigravity" { Convert-Antigravity $parsed $OutDir }
                "gemini-cli" { Convert-GeminiCli $parsed $OutDir }
                "opencode" { Convert-OpenCode $parsed $OutDir }
                "cursor" { Convert-Cursor $parsed $OutDir }
                "openclaw" { Convert-OpenClaw $parsed $OutDir }
                "qwen" { Convert-Qwen $parsed $OutDir }
                "aider" { Accumulate-Aider $parsed }
                "windsurf" { Accumulate-Windsurf $parsed }
            }
            $count++
        }
    }

    if ($t -eq "gemini-cli") {
        $extDir = Join-Path $OutDir "gemini-cli"
        $null = New-Item -ItemType Directory -Force -Path $extDir
        Set-Content -Path (Join-Path $extDir "gemini-extension.json") -Value "{`n  `"name`": `"agency-agents`",`n  `"version`": `"1.0.0`"`n}" -Encoding UTF8
        Write-Info "Wrote gemini-extension.json"
    }
    
    $total += $count
    Write-Info "Converted $count agents for $t"
}

if ($Tool -eq "all" -or $Tool -eq "aider") {
    $aiderDir = Join-Path $OutDir "aider"
    $null = New-Item -ItemType Directory -Force -Path $aiderDir
    Set-Content -Path (Join-Path $aiderDir "CONVENTIONS.md") -Value $global:AiderContent.ToString() -Encoding UTF8
    Write-Info "Wrote integrations/aider/CONVENTIONS.md"
}

if ($Tool -eq "all" -or $Tool -eq "windsurf") {
    $windsurfDir = Join-Path $OutDir "windsurf"
    $null = New-Item -ItemType Directory -Force -Path $windsurfDir
    Set-Content -Path (Join-Path $windsurfDir ".windsurfrules") -Value $global:WindsurfContent.ToString() -Encoding UTF8
    Write-Info "Wrote integrations/windsurf/.windsurfrules"
}

Write-Info "`nDone. Total conversions: $total"