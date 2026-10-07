<#
.SYNOPSIS
    Verify NewLife.Skills asset consistency.

.DESCRIPTION
    Scans .github/{instructions,skills,agents} and the global instruction file,
    then validates:
      1. Every asset has a valid YAML frontmatter with required fields (name/description).
      2. Each skill folder name matches its `name` field.
      3. README.md asset tables match disk in BOTH directions:
           - every disk asset is listed in README (no forgotten registration);
           - every README-listed asset exists on disk (no stale/phantom entry).

    Also flags legacy .github/prompts/*.prompt.md files: prompt files are deprecated
    for Agent Host sessions and must be migrated to skills.

    All files are read as UTF-8 (no BOM) via .NET to avoid PowerShell's default GBK
    corruption on Chinese content. The script NEVER modifies any file.

    Exits 1 when any problem is found (CI-friendly), 0 otherwise.

.PARAMETER RepoRoot
    Repository root. Defaults to the script's parent directory.

.EXAMPLE
    powershell -File scripts\verify-assets.ps1
        Run a full consistency check and print a report.
#>
param(
    [String]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Helpers ───────────────────────────────────────────────────────────────────
function ReadText([String]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function GetFrontmatter([String]$Text) {
    if ($Text -match '(?s)^\uFEFF?---\s*\r?\n(.*?)\r?\n---') { return $Matches[1] }
    return $null
}

function GetField([String]$Frontmatter, [String]$Key) {
    if ([String]::IsNullOrEmpty($Frontmatter)) { return $null }
    foreach ($line in ($Frontmatter -split '\r?\n')) {
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith($Key + ":")) {
            $val = $trimmed.Substring($Key.Length + 1).Trim()
            return $val.Trim('"').Trim("'").Trim()
        }
    }
    return $null
}

$problems = [System.Collections.Generic.List[String]]::new()

$githubDir  = Join-Path $RepoRoot ".github"
$readmePath = Join-Path $RepoRoot "README.md"
$skillsDir  = Join-Path $githubDir "skills"
$instrDir   = Join-Path $githubDir "instructions"
$agentsDir  = Join-Path $githubDir "agents"
$legacyPromptsDir = Join-Path $githubDir "prompts"

# Identifiers a README table cell may legitimately reference.
$diskIds = [System.Collections.Generic.HashSet[String]]::new()
# Identifiers that MUST appear in README (registration check).
$mustList = [System.Collections.Generic.List[String]]::new()

# ── Skills ────────────────────────────────────────────────────────────────────
foreach ($d in (Get-ChildItem -Path $skillsDir -Directory)) {
    [void]$diskIds.Add($d.Name)
    $mustList.Add($d.Name)
    $skillMd = Join-Path $d.FullName "SKILL.md"
    if (-not (Test-Path $skillMd)) { $problems.Add("Skill missing SKILL.md: $($d.Name)"); continue }
    $fm = GetFrontmatter (ReadText $skillMd)
    if ($null -eq $fm) { $problems.Add("Skill missing frontmatter: $($d.Name)"); continue }
    $name = GetField $fm "name"
    $desc = GetField $fm "description"
    if ($null -eq $name) { $problems.Add("Skill missing 'name': $($d.Name)") }
    elseif ($name -ne $d.Name) { $problems.Add("Skill name/folder mismatch: folder=$($d.Name) name=$name") }
    if ([String]::IsNullOrWhiteSpace($desc)) { $problems.Add("Skill missing 'description': $($d.Name)") }
}

# ── Instructions ──────────────────────────────────────────────────────────────
foreach ($f in (Get-ChildItem -Path $instrDir -Filter "*.instructions.md")) {
    [void]$diskIds.Add($f.Name)
    $mustList.Add($f.Name)
    $fm = GetFrontmatter (ReadText $f.FullName)
    if ($null -eq $fm) { $problems.Add("Instruction missing frontmatter: $($f.Name)"); continue }
    $desc = GetField $fm "description"
    if ([String]::IsNullOrWhiteSpace($desc)) { $problems.Add("Instruction missing 'description': $($f.Name)") }
}

# ── Agents ────────────────────────────────────────────────────────────────────
foreach ($f in (Get-ChildItem -Path $agentsDir -Filter "*.agent.md")) {
    $shortName = $f.Name -replace '\.agent\.md$', ''
    [void]$diskIds.Add($f.Name)
    [void]$diskIds.Add($shortName)
    $mustList.Add($shortName)
    $fm = GetFrontmatter (ReadText $f.FullName)
    if ($null -eq $fm) { $problems.Add("Agent missing frontmatter: $($f.Name)"); continue }
    $desc = GetField $fm "description"
    if ([String]::IsNullOrWhiteSpace($desc)) { $problems.Add("Agent missing 'description': $($f.Name)") }
}

# ── Legacy prompts (prompt files are deprecated for Agent Host; migrate to skills) ──
if (Test-Path $legacyPromptsDir) {
    foreach ($f in (Get-ChildItem -Path $legacyPromptsDir -Filter "*.prompt.md")) {
        $problems.Add("Legacy prompt file (migrate to a skill): $($f.Name)")
    }
}

# ── README cross-check ────────────────────────────────────────────────────────
$readme = ReadText $readmePath
$readmeNames = [System.Collections.Generic.List[String]]::new()
# Table rows whose first cell is a single backticked identifier: | `name` | ... |
foreach ($m in [regex]::Matches($readme, '(?m)^\|\s*`([^`]+)`\s*\|')) {
    [void]$readmeNames.Add($m.Groups[1].Value)
}

foreach ($id in $mustList) {
    if ($readmeNames -notcontains $id) { $problems.Add("Disk asset not listed in README: $id") }
}
foreach ($n in $readmeNames) {
    if (-not $diskIds.Contains($n)) { $problems.Add("README lists non-existent asset: $n") }
}

# ── Agent quick table cross-check (copilot-instructions.md §1.5) ──────────────
$instrPath = Join-Path $githubDir "copilot-instructions.md"
if (-not (Test-Path $instrPath)) {
    $problems.Add("copilot-instructions.md not found")
} else {
    $section = [regex]::Match((ReadText $instrPath), '(?s)### 1\.5.*?\r?\n---')
    if (-not $section.Success) {
        $problems.Add("copilot-instructions §1.5 (Agent quick table) section not found")
    } else {
        $listedNames = [System.Collections.Generic.List[String]]::new()
        foreach ($m in [regex]::Matches($section.Value, '\*\*([^*\r\n]+?)\*\*')) {
            [void]$listedNames.Add($m.Groups[1].Value.Trim())
        }
        $agentNames = [System.Collections.Generic.List[String]]::new()
        foreach ($f in (Get-ChildItem -Path $agentsDir -Filter "*.agent.md")) {
            $nm = GetField (GetFrontmatter (ReadText $f.FullName)) "name"
            if (-not [String]::IsNullOrWhiteSpace($nm)) { [void]$agentNames.Add($nm) }
        }
        foreach ($nm in $agentNames) {
            if ($listedNames -notcontains $nm) { $problems.Add("Agent missing from copilot-instructions §1.5 quick table: $nm") }
        }
        foreach ($nm in $listedNames) {
            if ($agentNames -notcontains $nm) { $problems.Add("copilot-instructions §1.5 lists non-existent agent: $nm") }
        }
    }
}

# ── Report ────────────────────────────────────────────────────────────────────
$skillCount = (Get-ChildItem -Path $skillsDir -Directory).Count
$instrCount = (Get-ChildItem -Path $instrDir -Filter "*.instructions.md").Count
$agentCount = (Get-ChildItem -Path $agentsDir -Filter "*.agent.md").Count

Write-Host ""
Write-Host "NewLife.Skills asset verification" -ForegroundColor Cyan
Write-Host ("  skills={0}  instructions={1}  agents={2}" -f $skillCount, $instrCount, $agentCount)

if ($problems.Count -eq 0) {
    Write-Host "  OK: all assets consistent." -ForegroundColor Green
    exit 0
}

Write-Host ("  {0} problem(s) found:" -f $problems.Count) -ForegroundColor Yellow
foreach ($p in $problems) { Write-Host "    - $p" -ForegroundColor Yellow }
exit 1
