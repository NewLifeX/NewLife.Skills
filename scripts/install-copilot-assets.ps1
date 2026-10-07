<#
.SYNOPSIS
    安装 / 更新 / 卸载 NewLife Copilot 资产到 VS Code 用户数据目录。

.DESCRIPTION
    将 .github/ 下的 skills/instructions/agents 同步到 Copilot 官方用户目录：
      Skills        → %USERPROFILE%\.copilot\skills\<name>\
      Instructions  → %USERPROFILE%\.copilot\instructions\*.instructions.md
      Agents        → %USERPROFILE%\.copilot\agents\*.agent.md
      全局指令      → %USERPROFILE%\.copilot\instructions\newlife-global.instructions.md

    通过 manifest 文件 (~/.copilot/newlife-skills-manifest.json) 跟踪本工具安装过的资产，
    再次执行安装时会**自动删除**仓库中已不存在但上次安装过的资产（孤儿清理）。
    从旧版脚本升级（资产装在 %APPDATA%\Code\User\prompts，更早的初版脚本把 Agents 装在
    %APPDATA%\Code\User\chatmodes）时，安装后自动清理旧位置的同名副本（含已废弃的
    *.prompt.md）；加 -KeepLegacy 可保留旧位置文件。
    不会触碰仓库资产清单与 manifest 之外的文件，保证用户自有资产安全。

    支持平台：Win10 / Win11 + VS Code + GitHub Copilot Chat

.PARAMETER RepoRoot
    仓库根目录，默认为脚本目录的父目录。

.PARAMETER WhatIf
    预览将要安装/删除的内容，不实际执行。

.PARAMETER Uninstall
    根据 manifest 卸载本工具安装过的所有资产，然后退出。

.PARAMETER NoOrphanCleanup
    安装时不清理孤儿资产（仅做覆盖式更新）。一般不需要。

.PARAMETER KeepLegacy
    保留旧位置（%APPDATA%\Code\User\prompts、%APPDATA%\Code\User\chatmodes）下的同名资产副本，不做迁移清理。

.PARAMETER AssumeAllOrphans
    首次升级专用：manifest 不存在时，把目标目录（含旧位置 prompts / chatmodes）中所有符合
    本工具命名规则的资产（skills/ 子目录、*.instructions.md、*.agent.md、*.prompt.md）视为
    上次安装过，本次仓库中不存在的都会被清理。
    ⚠ 会误删同名但非本工具安装的文件，请先加 -WhatIf 预览。

.EXAMPLE
    .\install-copilot-assets.ps1
        安装或更新（默认会自动删除已废弃资产）

.EXAMPLE
    .\install-copilot-assets.ps1 -WhatIf
        预览将做什么改动

.EXAMPLE
    .\install-copilot-assets.ps1 -AssumeAllOrphans -WhatIf
        首次从旧脚本迁移：先预览会清理哪些老资产，确认后去掉 -WhatIf 实际执行

.EXAMPLE
    .\install-copilot-assets.ps1 -Uninstall
        卸载本工具安装过的全部资产
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$WhatIf,
    [switch]$Uninstall,
    [switch]$NoOrphanCleanup,
    [switch]$KeepLegacy,
    [switch]$AssumeAllOrphans
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Path Setup ────────────────────────────────────────────────────────────────
$githubDir       = Join-Path $RepoRoot ".github"
# Copilot 官方用户目录：~/.copilot/（Agent Host 会话从此读取用户级资产）
$copilotHome     = Join-Path $env:USERPROFILE ".copilot"
$skillsDst       = Join-Path $copilotHome "skills"
$instrDst        = Join-Path $copilotHome "instructions"
$agentsDst       = Join-Path $copilotHome "agents"
$manifestPath    = Join-Path $copilotHome "newlife-skills-manifest.json"

# 旧版安装位置（迁移清理用），不再主动创建
#   prompts   —— 中期版本位置（Instructions / Agents）
#   chatmodes —— 初版位置（仅 Agents）
$legacyDst       = Join-Path (Join-Path $env:APPDATA "Code\User") "prompts"
$chatmodesDst    = Join-Path (Join-Path $env:APPDATA "Code\User") "chatmodes"
$skillsDstOld    = Join-Path $legacyDst "skills"
$manifestPathOld = Join-Path $legacyDst "newlife-skills-manifest.json"

$skillsSrc       = Join-Path $githubDir "skills"
$instructionsSrc = Join-Path $githubDir "instructions"
$agentsSrc       = Join-Path $githubDir "agents"
$globalInstrSrc  = Join-Path $githubDir "copilot-instructions.md"

$globalInstrName = "newlife-global.instructions.md"

# ── Helpers ───────────────────────────────────────────────────────────────────
function EnsureDir ([String]$Path) {
    if (-not (Test-Path $Path)) {
        if ($WhatIf) { return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function WriteStep ([String]$Tag, [String]$Msg, [ConsoleColor]$Color = 'DarkCyan') {
    Write-Host ("    [{0,-7}] {1}" -f $Tag, $Msg) -ForegroundColor $Color
}

function ReadManifest {
    # 优先读新位置；旧位置 manifest 用于首次升级迁移
    $path = $manifestPath
    if (-not (Test-Path $path) -and (Test-Path $manifestPathOld)) { $path = $manifestPathOld }
    if (-not (Test-Path $path)) { return @() }
    try {
        $obj = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $obj.assets) { return @() }
        return @($obj.assets)
    } catch {
        Write-Host "  ⚠ 旧 manifest 解析失败，按全新安装处理：$($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

function WriteManifest ([String[]]$Assets) {
    $obj = [PSCustomObject]@{
        version     = 1
        installedAt = (Get-Date).ToString("o")
        repoRoot    = $RepoRoot
        assets      = $Assets
    }
    $json = $obj | ConvertTo-Json -Depth 4
    if ($WhatIf) { return }
    [System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))
}

# 资产相对路径约定：
#   - skill 文件夹："skills/<name>"              → ~/.copilot/skills/<name>（旧：prompts\skills\）
#   - 指令文件：    "<filename>.instructions.md" → ~/.copilot/instructions/（旧：prompts\）
#   - Agent 文件：  "<filename>.agent.md"        → ~/.copilot/agents/（旧：prompts\，初版：chatmodes\）
#   - 旧版提示文件："<filename>.prompt.md"       → 仅存在于旧位置 prompts\
function GetAssetLocations ([String]$RelPath) {
    $list = New-Object System.Collections.Generic.List[String]
    if ($RelPath.StartsWith("skills/", [StringComparison]::OrdinalIgnoreCase)) {
        $name = $RelPath.Substring(7)
        $list.Add((Join-Path $skillsDst $name))
        $list.Add((Join-Path $skillsDstOld $name))
    }
    elseif ($RelPath.EndsWith(".instructions.md", [StringComparison]::OrdinalIgnoreCase)) {
        $list.Add((Join-Path $instrDst $RelPath))
        $list.Add((Join-Path $legacyDst $RelPath))
    }
    elseif ($RelPath.EndsWith(".agent.md", [StringComparison]::OrdinalIgnoreCase)) {
        $list.Add((Join-Path $agentsDst $RelPath))
        $list.Add((Join-Path $legacyDst $RelPath))
        $list.Add((Join-Path $chatmodesDst $RelPath))
    }
    else {
        $list.Add((Join-Path $legacyDst $RelPath))
    }
    return $list
}

function RemoveAsset ([String]$RelPath) {
    $removed = $false
    foreach ($full in (GetAssetLocations $RelPath)) {
        if (Test-Path $full) {
            if (-not $WhatIf) { Remove-Item -Path $full -Recurse -Force }
            $removed = $true
        }
    }
    return $removed
}

# 迁移清理：新位置已就位后，删除旧位置下的同名副本（Agents 同时清理初版 chatmodes 位置）
function RemoveLegacyCopy ([String]$RelPath) {
    $olds = New-Object System.Collections.Generic.List[String]
    if ($RelPath.StartsWith("skills/", [StringComparison]::OrdinalIgnoreCase)) {
        $olds.Add((Join-Path $skillsDstOld ($RelPath.Substring(7))))
    }
    elseif ($RelPath.EndsWith(".agent.md", [StringComparison]::OrdinalIgnoreCase)) {
        $olds.Add((Join-Path $legacyDst $RelPath))
        $olds.Add((Join-Path $chatmodesDst $RelPath))
    }
    else {
        $olds.Add((Join-Path $legacyDst $RelPath))
    }
    $removed = $false
    foreach ($full in $olds) {
        if (Test-Path $full) {
            if (-not $WhatIf) { Remove-Item -Path $full -Recurse -Force }
            $removed = $true
        }
    }
    return $removed
}

function CopyFileAsset ([String]$SrcFile, [String]$DstDir) {
    if ($WhatIf) { return }
    Copy-Item -Path $SrcFile -Destination (Join-Path $DstDir (Split-Path $SrcFile -Leaf)) -Force
}

function CopySkillFolder ([System.IO.DirectoryInfo]$SrcDir) {
    $dst = Join-Path $skillsDst $SrcDir.Name
    if ($WhatIf) { return }
    # 先清空旧子目录内容（保留目录），再整体复制，避免遗留旧文件
    if (Test-Path $dst) { Remove-Item -Path $dst -Recurse -Force }
    EnsureDir $dst
    Copy-Item -Path (Join-Path $SrcDir.FullName "*") -Destination $dst -Recurse -Force
}

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== NewLife Copilot 资产安装 ===" -ForegroundColor Green
Write-Host "  仓库: $RepoRoot"
Write-Host "  目标: $copilotHome"
Write-Host "        (skills\  instructions\  agents\)"
if ($WhatIf)    { Write-Host "  模式: 预览（WhatIf）" -ForegroundColor Yellow }
if ($Uninstall) { Write-Host "  模式: 卸载（Uninstall）" -ForegroundColor Yellow }
Write-Host ""

if (-not $Uninstall -and -not (Test-Path $githubDir)) {
    Write-Error "未找到 .github 目录: $githubDir"
    exit 1
}

EnsureDir $skillsDst
EnsureDir $instrDst
EnsureDir $agentsDst
# 迁移模式：存在旧 manifest、初版 chatmodes 目录，或显式 -AssumeAllOrphans 时，安装后清理旧位置副本
$migrateLegacy = (-not $KeepLegacy) -and ($AssumeAllOrphans -or (Test-Path $manifestPathOld) -or (Test-Path $chatmodesDst))
if ($migrateLegacy -and ((Test-Path $legacyDst) -or (Test-Path $chatmodesDst))) {
    Write-Host "  ⚠ 检测到旧版安装位置，安装后将清理旧位置同名副本" -ForegroundColor Yellow
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
if ($Uninstall) {
    $oldAssets = @(ReadManifest)
    if ($oldAssets.Count -eq 0) {
        Write-Host "  未找到 manifest，无可卸载内容。" -ForegroundColor DarkGray
        exit 0
    }
    Write-Host "[卸载] 移除 $($oldAssets.Count) 项资产" -ForegroundColor Yellow
    $removed = 0
    foreach ($a in $oldAssets) {
        if (RemoveAsset $a) {
            WriteStep 'remove' $a 'DarkGray'
            $removed++
        }
    }
    if (-not $WhatIf) {
        Remove-Item -Path $manifestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $manifestPathOld -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
    Write-Host "=== 卸载完成，移除 $removed 项 ===" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ── Build New Manifest from Source ────────────────────────────────────────────
$newAssets = New-Object System.Collections.Generic.List[String]

# Skills
$skillFolders = @()
if (Test-Path $skillsSrc) {
    $skillFolders = @(Get-ChildItem -Path $skillsSrc -Directory | Sort-Object Name)
    foreach ($f in $skillFolders) { $newAssets.Add("skills/$($f.Name)") }
}

# Instructions
$instructionFiles = @()
if (Test-Path $instructionsSrc) {
    $instructionFiles = @(Get-ChildItem -Path $instructionsSrc -Filter "*.instructions.md" -File | Sort-Object Name)
    foreach ($f in $instructionFiles) { $newAssets.Add($f.Name) }
}

# Agents
$agentFiles = @()
if (Test-Path $agentsSrc) {
    $agentFiles = @(Get-ChildItem -Path $agentsSrc -Filter "*.agent.md" -File | Sort-Object Name)
    foreach ($f in $agentFiles) { $newAssets.Add($f.Name) }
}

# 全局 Copilot 指令（必有）
if (Test-Path $globalInstrSrc) {
    $newAssets.Add($globalInstrName)
}

# ── Orphan Cleanup ────────────────────────────────────────────────────────────
$oldAssets = @(ReadManifest)
# -AssumeAllOrphans：无视 manifest，从磁盘重扫所有符合命名规则的资产
# 适用于首次从旧脚本迁移、或 manifest 损坏后希望一次性彻底同步
if ($AssumeAllOrphans) {
    Write-Host "[迁移扫描] 将磁盘上所有本工具命名规则的资产视为旧安装" -ForegroundColor Yellow
    $virtual = New-Object System.Collections.Generic.List[String]
    # 新技能路径
    if (Test-Path $skillsDst) {
        Get-ChildItem -Path $skillsDst -Directory | ForEach-Object { $virtual.Add("skills/$($_.Name)") }
    }
    # 旧技能路径（兼容清理）
    if (Test-Path $skillsDstOld) {
        Get-ChildItem -Path $skillsDstOld -Directory | ForEach-Object { $virtual.Add("skills/$($_.Name)") }
    }
    # 旧位置文件（prompts 含已废弃的 *.prompt.md；chatmodes 为初版 Agents 位置）；不扫描
    # ~/.copilot/agents、~/.copilot/instructions，避免误把用户自有的 Agent / 指令文件当作本工具安装过的资产
    if (Test-Path $legacyDst) {
        Get-ChildItem -Path $legacyDst -Filter "*.instructions.md" -File | ForEach-Object { $virtual.Add($_.Name) }
        Get-ChildItem -Path $legacyDst -Filter "*.agent.md" -File | ForEach-Object { $virtual.Add($_.Name) }
        Get-ChildItem -Path $legacyDst -Filter "*.prompt.md" -File | ForEach-Object { $virtual.Add($_.Name) }
    }
    if (Test-Path $chatmodesDst) {
        Get-ChildItem -Path $chatmodesDst -Filter "*.agent.md" -File | ForEach-Object { $virtual.Add($_.Name) }
    }
    $oldAssets = @($virtual | Select-Object -Unique)
    Write-Host "    发现 $($oldAssets.Count) 项候选资产" -ForegroundColor DarkGray
}
$orphans = @()
if ($oldAssets.Count -gt 0 -and -not $NoOrphanCleanup) {
    $newSet = [System.Collections.Generic.HashSet[String]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $newAssets | ForEach-Object { [void]$newSet.Add($_) }
    foreach ($a in $oldAssets) {
        if (-not $newSet.Contains($a)) { $orphans += $a }
    }
}

if ($orphans.Count -gt 0) {
    Write-Host "[孤儿清理] 仓库中已删除但上次安装过的 $($orphans.Count) 项" -ForegroundColor Yellow
    foreach ($o in $orphans) {
        if (RemoveAsset $o) {
            WriteStep 'orphan' $o 'DarkGray'
        }
    }
}

# ── Install / Update ──────────────────────────────────────────────────────────
$installed = 0
$legacyCleaned = 0

# 1. Skills
Write-Host "[1/4] Skills ($($skillFolders.Count))" -ForegroundColor Yellow
foreach ($folder in $skillFolders) {
    CopySkillFolder $folder
    WriteStep 'skill' $folder.Name
    $installed++
}
if ($skillFolders.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 2. Instructions
Write-Host "[2/4] Instructions ($($instructionFiles.Count))" -ForegroundColor Yellow
foreach ($f in $instructionFiles) {
    CopyFileAsset $f.FullName $instrDst
    WriteStep 'instr' $f.Name
    $installed++
}
if ($instructionFiles.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 3. Agents
Write-Host "[3/4] Agents ($($agentFiles.Count))" -ForegroundColor Yellow
foreach ($f in $agentFiles) {
    CopyFileAsset $f.FullName $agentsDst
    WriteStep 'agent' $f.Name
    $installed++
}
if ($agentFiles.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 4. 全局 Copilot 指令（注入 applyTo 头部）
Write-Host "[4/4] 全局 Copilot 指令" -ForegroundColor Yellow
if (Test-Path $globalInstrSrc) {
    $content = Get-Content -Path $globalInstrSrc -Raw -Encoding UTF8
    $wrapped = "---`napplyTo: `"**`"`n---`n" + $content
    $dstFile = Join-Path $instrDst $globalInstrName
    if (-not $WhatIf) {
        [System.IO.File]::WriteAllText($dstFile, $wrapped, [System.Text.UTF8Encoding]::new($false))
    }
    WriteStep 'global' $globalInstrName
    $installed++
} else {
    Write-Host "    （跳过：$globalInstrSrc 不存在）" -ForegroundColor DarkGray
}

# ── 旧位置迁移清理 ────────────────────────────────────────────────────────────
if ($migrateLegacy -and ((Test-Path $legacyDst) -or (Test-Path $chatmodesDst))) {
    foreach ($a in $newAssets) {
        if (RemoveLegacyCopy $a) { $legacyCleaned++ }
    }
    if ($legacyCleaned -gt 0) {
        Write-Host "[迁移] 清理旧位置同名副本 $legacyCleaned 项" -ForegroundColor Yellow
    }
    # 旧技能目录为空则删除
    if ((Test-Path $skillsDstOld) -and -not $WhatIf -and @(Get-ChildItem -Path $skillsDstOld -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -Path $skillsDstOld -Force -ErrorAction SilentlyContinue
    }
    # 初版 chatmodes 目录为空则删除
    if ((Test-Path $chatmodesDst) -and -not $WhatIf -and @(Get-ChildItem -Path $chatmodesDst -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -Path $chatmodesDst -Force -ErrorAction SilentlyContinue
    }
}

# ── Write Manifest ────────────────────────────────────────────────────────────
WriteManifest $newAssets
# 旧位置 manifest 已被新位置取代，迁移模式下删除
if ($migrateLegacy -and (Test-Path $manifestPathOld) -and -not $WhatIf) {
    Remove-Item -Path $manifestPathOld -Force -ErrorAction SilentlyContinue
}

# ── 完成 ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== 安装完成 ===" -ForegroundColor Green
Write-Host "  安装/更新: $installed 项"
Write-Host "  孤儿清理: $($orphans.Count) 项"
Write-Host "  旧位置迁移: $legacyCleaned 项"
Write-Host "  Manifest : $manifestPath"
Write-Host ""
Write-Host "重启 VS Code 后即可在所有项目中使用。"
Write-Host ""
