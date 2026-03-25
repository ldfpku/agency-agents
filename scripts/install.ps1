<#
.SYNOPSIS
install.ps1 -- Install The Agency agents into your local agentic tool(s).

.DESCRIPTION
Reads converted files from integrations/ and copies them to the appropriate
config directory for each tool. Run scripts/convert.ps1 first if integrations/
is missing or stale.
#>
[CmdletBinding()]
param(
    [string]$Tool = "all",
    [switch]$Interactive,
    [switch]$NoInteractive,
    [switch]$Parallel,
    [int]$Jobs = 4,
    [switch]$Worker  # Internal flag used for parallel execution
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$SCRIPT_DIR = $PSScriptRoot
$REPO_ROOT = Split-Path $SCRIPT_DIR -Parent
$INTEGRATIONS = Join-Path $REPO_ROOT "integrations"

$ALL_TOOLS = @("claude-code", "copilot", "antigravity", "gemini-cli", "opencode", "openclaw", "cursor", "aider", "windsurf", "qwen")

# ---------------------------------------------------------------------------
# Output Helpers
# ---------------------------------------------------------------------------
function Write-Ok([string]$msg) { Write-Host "[OK]  " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn([string]$msg) { Write-Host "[!!]  " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err([string]$msg) { Write-Host "[ERR] " -ForegroundColor Red -NoNewline; Write-Host $msg }
function Write-Header([string]$msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Dim([string]$msg) { Write-Host $msg -ForegroundColor DarkGray }

function Write-BoxTop { Write-Host "  +------------------------------------------------+" }
function Write-BoxBot { Write-Host "  +------------------------------------------------+" }
function Write-BoxRow([string]$text, [string]$color="None") {
    $cleanText = $text -replace '\e\[[0-9;]*m', ''
    $pad = 48 - 2 - $cleanText.Length
    if ($pad -lt 0) { $pad = 0 }
    Write-Host "  | " -NoNewline
    if ($color -ne "None") { Write-Host $text -ForegroundColor $color -NoNewline }
    else { Write-Host $text -NoNewline }
    Write-Host (" " * $pad) -NoNewline
    Write-Host " |"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if (-not (Test-Path $INTEGRATIONS)) {
    Write-Err "integrations/ not found. Run ./scripts/convert.ps1 first."
    exit 1
}

# ---------------------------------------------------------------------------
# Tool detection
# ---------------------------------------------------------------------------
function Detect-Tool([string]$toolName) {
    switch ($toolName) {
        "claude-code" { return (Test-Path (Join-Path $HOME ".claude")) }
        "copilot"     { return ([bool](Get-Command code -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".github")) -or (Test-Path (Join-Path $HOME ".copilot"))) }
        "antigravity" { return (Test-Path (Join-Path $HOME ".gemini/antigravity/skills")) }
        "gemini-cli"  { return ([bool](Get-Command gemini -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".gemini"))) }
        "opencode"    { return ([bool](Get-Command opencode -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".config/opencode"))) }
        "openclaw"    { return ([bool](Get-Command openclaw -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".openclaw"))) }
        "cursor"      { return ([bool](Get-Command cursor -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".cursor"))) }
        "aider"       { return ([bool](Get-Command aider -ErrorAction SilentlyContinue)) }
        "windsurf"    { return ([bool](Get-Command windsurf -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".codeium"))) }
        "qwen"        { return ([bool](Get-Command qwen -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $HOME ".qwen"))) }
        default       { return $false }
    }
}

function Get-ToolLabel([string]$toolName) {
    $name = ""; $desc = ""
    switch ($toolName) {
        "claude-code" { $name = "Claude Code"; $desc = "(claude.ai/code)" }
        "copilot"     { $name = "Copilot"; $desc = "(~/.github + ~/.copilot)" }
        "antigravity" { $name = "Antigravity"; $desc = "(~/.gemini/antigravity)" }
        "gemini-cli"  { $name = "Gemini CLI"; $desc = "(gemini extension)" }
        "opencode"    { $name = "OpenCode"; $desc = "(opencode.ai)" }
        "openclaw"    { $name = "OpenClaw"; $desc = "(~/.openclaw)" }
        "cursor"      { $name = "Cursor"; $desc = "(.cursor/rules)" }
        "aider"       { $name = "Aider"; $desc = "(CONVENTIONS.md)" }
        "windsurf"    { $name = "Windsurf"; $desc = "(.windsurfrules)" }
        "qwen"        { $name = "Qwen Code"; $desc = "(~/.qwen/agents)" }
    }
    return "$($name.PadRight(14))  $desc"
}

# ---------------------------------------------------------------------------
# Interactive selector
# ---------------------------------------------------------------------------
function Interactive-Select {
    $selected = @(0) * $ALL_TOOLS.Length
    $detected_map = @(0) * $ALL_TOOLS.Length
    for ($i = 0; $i -lt $ALL_TOOLS.Length; $i++) {
        if (Detect-Tool $ALL_TOOLS[$i]) {
            $selected[$i] = 1; $detected_map[$i] = 1
        }
    }

    while ($true) {
        Clear-Host
        Write-Host "`n"
        Write-BoxTop
        Write-BoxRow "  The Agency -- Tool Installer" "Cyan"
        Write-BoxBot
        Write-Host "`n  System scan:  [*] = detected on this machine`n" -ForegroundColor DarkGray

        for ($i = 0; $i -lt $ALL_TOOLS.Length; $i++) {
            $num = $i + 1
            $t = $ALL_TOOLS[$i]
            $label = Get-ToolLabel $t
            $dot = if ($detected_map[$i] -eq 1) { "[*]" } else { "[ ]" }
            $chk = if ($selected[$i] -eq 1) { "[x]" } else { "[ ]" }
            $dotColor = if ($detected_map[$i] -eq 1) { "Green" } else { "DarkGray" }
            $chkColor = if ($selected[$i] -eq 1) { "Green" } else { "DarkGray" }

            Write-Host "  " -NoNewline
            Write-Host $chk -ForegroundColor $chkColor -NoNewline
            Write-Host "  $num)  " -NoNewline
            Write-Host $dot -ForegroundColor $dotColor -NoNewline
            Write-Host "  $label"
        }

        Write-Host "`n  ------------------------------------------------"
        Write-Host "  [1-$($ALL_TOOLS.Length)] toggle   [a] all   [n] none   [d] detected" -ForegroundColor Cyan
        Write-Host "  [Enter] install   [q] quit" -ForegroundColor Green
        Write-Host "`n  >> " -NoNewline

        $inputStr = Read-Host

        switch -Regex ($inputStr) {
            "^(q|Q)$" { Write-Host "`n"; Write-Ok "Aborted."; exit 0 }
            "^(a|A)$" { for ($j=0; $j -lt $ALL_TOOLS.Length; $j++) { $selected[$j]=1 }; break }
            "^(n|N)$" { for ($j=0; $j -lt $ALL_TOOLS.Length; $j++) { $selected[$j]=0 }; break }
            "^(d|D)$" { for ($j=0; $j -lt $ALL_TOOLS.Length; $j++) { $selected[$j]=$detected_map[$j] }; break }
            "^$" {
                if ($selected -contains 1) {
                    $script:SELECTED_TOOLS = @()
                    for ($i=0; $i -lt $ALL_TOOLS.Length; $i++) {
                        if ($selected[$i] -eq 1) { $script:SELECTED_TOOLS += $ALL_TOOLS[$i] }
                    }
                    return
                } else {
                    Write-Host "  Nothing selected -- pick a tool or press q to quit." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                break
            }
            default {
                $toggled = $false
                $tokens = $inputStr -split '\s+'
                foreach ($token in $tokens) {
                    if ($token -match "^\d+$") {
                        $idx = [int]$token - 1
                        if ($idx -ge 0 -and $idx -lt $ALL_TOOLS.Length) {
                            $selected[$idx] = if ($selected[$idx] -eq 1) { 0 } else { 1 }
                            $toggled = $true
                        }
                    }
                }
                if (-not $toggled) {
                    Write-Host "  Invalid. Enter a number 1-$($ALL_TOOLS.Length), or a command." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------
$AgentDirs = @("academic","design","engineering","game-development","marketing","paid-media","sales","product","project-management","testing","support","spatial-computing","specialized")

function Install-ClaudeCode {
    $dest = "$HOME\.claude\agents"
    $count = 0
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($dir in $AgentDirs) {
        $target = Join-Path $REPO_ROOT $dir
        if (Test-Path $target) {
            $files = Get-ChildItem -Path $target -Filter "*.md" -File -Recurse
            foreach ($f in $files) {
                try {
                    $firstLine = Get-Content $f.FullName -TotalCount 1 -ErrorAction Stop
                    if ($firstLine -eq "---") {
                        Copy-Item $f.FullName -Destination $dest -Force
                        $count++
                    }
                } catch { }
            }
        }
    }
    Write-Ok "Claude Code: $count agents -> $dest"
}

function Install-Copilot {
    $dest_github = "$HOME\.github\agents"
    $dest_copilot = "$HOME\.copilot\agents"
    $count = 0
    New-Item -ItemType Directory -Force -Path $dest_github | Out-Null
    New-Item -ItemType Directory -Force -Path $dest_copilot | Out-Null
    foreach ($dir in $AgentDirs) {
        $target = Join-Path $REPO_ROOT $dir
        if (Test-Path $target) {
            $files = Get-ChildItem -Path $target -Filter "*.md" -File -Recurse
            foreach ($f in $files) {
                try {
                    $firstLine = Get-Content $f.FullName -TotalCount 1 -ErrorAction Stop
                    if ($firstLine -eq "---") {
                        Copy-Item $f.FullName -Destination $dest_github -Force
                        Copy-Item $f.FullName -Destination $dest_copilot -Force
                        $count++
                    }
                } catch { }
            }
        }
    }
    Write-Ok "Copilot: $count agents -> $dest_github"
    Write-Ok "Copilot: $count agents -> $dest_copilot"
}

function Install-Antigravity {
    $src = "$INTEGRATIONS\antigravity"
    $dest = "$HOME\.gemini\antigravity\skills"
    $count = 0
    if (-not (Test-Path $src)) { Write-Err "integrations/antigravity missing."; return }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $dirs = Get-ChildItem -Path $src -Directory
    foreach ($d in $dirs) {
        $name = $d.Name
        $targetDir = "$dest\$name"
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        if (Test-Path "$($d.FullName)\SKILL.md") {
            Copy-Item "$($d.FullName)\SKILL.md" -Destination "$targetDir\SKILL.md" -Force
            $count++
        }
    }
    Write-Ok "Antigravity: $count skills -> $dest"
}

function Install-GeminiCLI {
    $src = "$INTEGRATIONS\gemini-cli"
    $dest = "$HOME\.gemini\extensions\agency-agents"
    $count = 0
    $manifest = "$src\gemini-extension.json"
    $skills_dir = "$src\skills"
    if (-not (Test-Path $src)) { Write-Err "integrations/gemini-cli missing."; return }
    if (-not (Test-Path $manifest)) { Write-Err "$manifest missing."; return }
    if (-not (Test-Path $skills_dir)) { Write-Err "$skills_dir missing."; return }

    New-Item -ItemType Directory -Force -Path "$dest\skills" | Out-Null
    Copy-Item $manifest -Destination "$dest\gemini-extension.json" -Force

    $dirs = Get-ChildItem -Path $skills_dir -Directory
    foreach ($d in $dirs) {
        $name = $d.Name
        $targetDir = "$dest\skills\$name"
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        if (Test-Path "$($d.FullName)\SKILL.md") {
            Copy-Item "$($d.FullName)\SKILL.md" -Destination "$targetDir\SKILL.md" -Force
            $count++
        }
    }
    Write-Ok "Gemini CLI: $count skills -> $dest"
}

function Install-OpenCode {
    $src = "$INTEGRATIONS\opencode\agents"
    $dest = "$($PWD.Path)\.opencode\agents"
    $count = 0
    if (-not (Test-Path $src)) { Write-Err "integrations/opencode missing."; return }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -Path $src -Filter "*.md" -File | ForEach-Object {
        Copy-Item $_.FullName -Destination $dest -Force
        $count++
    }
    Write-Ok "OpenCode: $count agents -> $dest"
    Write-Warn "OpenCode: project-scoped. Run from your project root to install there."
}

function Install-OpenClaw {
    $src = "$INTEGRATIONS\openclaw"
    $dest = "$HOME\.openclaw\agency-agents"
    $count = 0
    if (-not (Test-Path $src)) { Write-Err "integrations/openclaw missing."; return }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -Path $src -Directory | ForEach-Object {
        $name = $_.Name
        $targetDir = "$dest\$name"
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        foreach ($file in @("SOUL.md", "AGENTS.md", "IDENTITY.md")) {
            if (Test-Path "$($_.FullName)\$file") { Copy-Item "$($_.FullName)\$file" -Destination "$targetDir\$file" -Force }
        }
        if (Get-Command openclaw -ErrorAction SilentlyContinue) {
            & openclaw agents add $name --workspace $targetDir --non-interactive | Out-Null
        }
        $count++
    }
    Write-Ok "OpenClaw: $count workspaces -> $dest"
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-Warn "OpenClaw: run 'openclaw gateway restart' to activate new agents"
    }
}

function Install-Cursor {
    $src = "$INTEGRATIONS\cursor\rules"
    $dest = "$($PWD.Path)\.cursor\rules"
    $count = 0
    if (-not (Test-Path $src)) { Write-Err "integrations/cursor missing."; return }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -Path $src -Filter "*.mdc" -File | ForEach-Object {
        Copy-Item $_.FullName -Destination $dest -Force
        $count++
    }
    Write-Ok "Cursor: $count rules -> $dest"
    Write-Warn "Cursor: project-scoped. Run from your project root to install there."
}

function Install-Aider {
    $src = "$INTEGRATIONS\aider\CONVENTIONS.md"
    $dest = "$($PWD.Path)\CONVENTIONS.md"
    if (-not (Test-Path $src)) { Write-Err "integrations/aider/CONVENTIONS.md missing."; return }
    if (Test-Path $dest) { Write-Warn "Aider: CONVENTIONS.md already exists at $dest (remove to reinstall)."; return }
    Copy-Item $src -Destination $dest
    Write-Ok "Aider: installed -> $dest"
    Write-Warn "Aider: project-scoped. Run from your project root to install there."
}

function Install-Windsurf {
    $src = "$INTEGRATIONS\windsurf\.windsurfrules"
    $dest = "$($PWD.Path)\.windsurfrules"
    if (-not (Test-Path $src)) { Write-Err "integrations/windsurf/.windsurfrules missing."; return }
    if (Test-Path $dest) { Write-Warn "Windsurf: .windsurfrules already exists at $dest (remove to reinstall)."; return }
    Copy-Item $src -Destination $dest
    Write-Ok "Windsurf: installed -> $dest"
    Write-Warn "Windsurf: project-scoped. Run from your project root to install there."
}

function Install-Qwen {
    $src = "$INTEGRATIONS\qwen\agents"
    $dest = "$($PWD.Path)\.qwen\agents"
    $count = 0
    if (-not (Test-Path $src)) { Write-Err "integrations/qwen missing."; return }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -Path $src -Filter "*.md" -File | ForEach-Object {
        Copy-Item $_.FullName -Destination $dest -Force
        $count++
    }
    Write-Ok "Qwen Code: installed $count agents to $dest"
    Write-Warn "Qwen Code: project-scoped. Run from your project root to install there."
    Write-Warn "Tip: Run '/agents manage' in Qwen Code to refresh, or restart session"
}

function Install-TargetTool([string]$ToolName) {
    switch ($ToolName) {
        "claude-code" { Install-ClaudeCode }
        "copilot"     { Install-Copilot }
        "antigravity" { Install-Antigravity }
        "gemini-cli"  { Install-GeminiCLI }
        "opencode"    { Install-OpenCode }
        "openclaw"    { Install-OpenClaw }
        "cursor"      { Install-Cursor }
        "aider"       { Install-Aider }
        "windsurf"    { Install-Windsurf }
        "qwen"        { Install-Qwen }
    }
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# Parallel Job Worker Mode
if ($Worker) {
    Install-TargetTool $Tool
    exit 0
}

$useInteractive = $false
if ($Interactive) {
    $useInteractive = $true
} elseif (-not $NoInteractive -and $Tool -eq "all" -and [Environment]::UserInteractive) {
    $useInteractive = $true
}

$script:SELECTED_TOOLS = @()

if ($useInteractive) {
    Interactive-Select
} elseif ($Tool -ne "all") {
    $script:SELECTED_TOOLS += $Tool
} else {
    Write-Header "The Agency -- Scanning for installed tools..."
    Write-Host "`n"
    foreach ($t in $ALL_TOOLS) {
        if (Detect-Tool $t) {
            $script:SELECTED_TOOLS += $t
            Write-Host "  " -NoNewline; Write-Host "[*]" -ForegroundColor Green -NoNewline; Write-Host "  $(Get-ToolLabel $t)  " -NoNewline; Write-Host "detected" -ForegroundColor DarkGray
        } else {
            Write-Host "  [ ]  $(Get-ToolLabel $t)  not found" -ForegroundColor DarkGray
        }
    }
}

if ($script:SELECTED_TOOLS.Length -eq 0) {
    Write-Warn "No tools selected or detected. Nothing to install."
    Write-Host "`n"
    Write-Dim "  Tip: use -Tool <name> to force-install a specific tool."
    Write-Dim "  Available: $($ALL_TOOLS -join ' ')"
    exit 0
}

Write-Header "The Agency -- Installing agents"
Write-Host "  Repo:       $REPO_ROOT"
$n_selected = $script:SELECTED_TOOLS.Length
Write-Host "  Installing: $($script:SELECTED_TOOLS -join ' ')"
if ($Parallel) { Write-Ok "Installing $n_selected tools in parallel (output buffered per tool)." }
Write-Host "`n"

$installed = 0

if ($Parallel) {
    $jobs = @()
    foreach ($t in $script:SELECTED_TOOLS) {
        $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "-Tool", $t, "-Worker")
        $jobs += Start-Job -ScriptBlock { & powershell.exe $args } -ArgumentList $psArgs
    }
    $jobs | Wait-Job | Receive-Job | ForEach-Object { Write-Host $_ }
    $jobs | Remove-Job
    $installed = $n_selected
} else {
    for ($i=0; $i -lt $n_selected; $i++) {
        $t = $script:SELECTED_TOOLS[$i]
        $current = $i + 1
        Write-Host "  [$current/$n_selected] $t" -ForegroundColor DarkGray
        Install-TargetTool $t
        $installed++
        Write-Host "`n" -NoNewline
    }
}

Write-BoxTop
Write-BoxRow "Done!  Installed $installed tool(s)." "Green"
Write-BoxBot
Write-Host "`n"
Write-Dim "  Run .\scripts\convert.ps1 to regenerate after adding or editing agents."
Write-Host "`n"