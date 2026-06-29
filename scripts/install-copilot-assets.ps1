<#
.SYNOPSIS
    安装 / 更新 / 卸载 NewLife Copilot 资产到 VS Code 用户数据目录。

.DESCRIPTION
    将 .github/ 下的 skills/instructions/prompts/agents 同步到 VS Code Copilot 用户目录：
      Skills        → %USERPROFILE%\.copilot\skills\<name>\   （Copilot 官方用户技能路径）
      Instructions  → %APPDATA%\Code\User\prompts\*.instructions.md
      Prompts       → %APPDATA%\Code\User\prompts\*.prompt.md
      Agents        → %APPDATA%\Code\User\prompts\*.agent.md
      全局指令      → %APPDATA%\Code\User\prompts\newlife-global.instructions.md

    通过 manifest 文件 (newlife-skills-manifest.json) 跟踪本工具安装过的资产，
    再次执行安装时会**自动删除**仓库中已不存在但上次安装过的资产（孤儿清理）。
    不会触碰 manifest 之外的文件，保证用户自有资产安全。

    支持平台：Win10 / Win11 + VS Code + GitHub Copilot Chat

.PARAMETER RepoRoot
    仓库根目录，默认为脚本目录的父目录。

.PARAMETER WhatIf
    预览将要安装/删除的内容，不实际执行。

.PARAMETER Uninstall
    根据 manifest 卸载本工具安装过的所有资产，然后退出。

.PARAMETER NoOrphanCleanup
    安装时不清理孤儿资产（仅做覆盖式更新）。一般不需要。

.PARAMETER AssumeAllOrphans
    首次升级专用：manifest 不存在时，把目标目录中所有符合本工具命名规则的资产
    （skills/ 子目录、*.instructions.md、*.agent.md、*.prompt.md）视为上次安装过，
    本次仓库中不存在的都会被清理。
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
    [switch]$AssumeAllOrphans
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── Path Setup ────────────────────────────────────────────────────────────────
$githubDir       = Join-Path $RepoRoot ".github"
$userDataDir     = Join-Path $env:APPDATA "Code\User"
$promptsDst      = Join-Path $userDataDir "prompts"
# Copilot 官方用户技能路径：~/.copilot/skills/（非 prompts/skills/）
$skillsDst       = Join-Path "$env:USERPROFILE\.copilot" "skills"
# 旧版本错装在 prompts/skills/ 下，升级后自动清理
$skillsDstOld    = Join-Path $promptsDst "skills"
$manifestPath    = Join-Path $promptsDst "newlife-skills-manifest.json"

$skillsSrc       = Join-Path $githubDir "skills"
$instructionsSrc = Join-Path $githubDir "instructions"
$promptsSrc      = Join-Path $githubDir "prompts"
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
    if (-not (Test-Path $manifestPath)) { return @() }
    try {
        $obj = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
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
#   - skill 文件夹：  "skills/<name>"  → 新在 %USERPROFILE%\.copilot\skills\，旧在 prompts\skills\
#   - 文件资产：       "<filename>.ext" → %APPDATA%\Code\User\prompts\
function RemoveAsset ([String]$RelPath) {
    if ($RelPath.StartsWith("skills/", [StringComparison]::OrdinalIgnoreCase)) {
        # 技能类资产：同时尝试新旧两个位置
        $removed = $false
        $fullNew = Join-Path $skillsDst ($RelPath.Substring(7))
        $fullOld = Join-Path $skillsDstOld ($RelPath.Substring(7))
        foreach ($full in @($fullNew, $fullOld)) {
            if (Test-Path $full) {
                if (-not $WhatIf) { Remove-Item -Path $full -Recurse -Force }
                $removed = $true
            }
        }
        return $removed
    }
    $full = Join-Path $promptsDst $RelPath
    if (-not (Test-Path $full)) { return $false }
    if ($WhatIf) { return $true }
    Remove-Item -Path $full -Recurse -Force
    return $true
}

function CopyFileAsset ([String]$SrcFile, [String]$DstName) {
    $dst = Join-Path $promptsDst $DstName
    if ($WhatIf) { return }
    Copy-Item -Path $SrcFile -Destination $dst -Force
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
Write-Host "  目标 (技能): $skillsDst"
Write-Host "  目标 (指令等): $promptsDst"
if ($WhatIf)    { Write-Host "  模式: 预览（WhatIf）" -ForegroundColor Yellow }
if ($Uninstall) { Write-Host "  模式: 卸载（Uninstall）" -ForegroundColor Yellow }
Write-Host ""

if (-not $Uninstall -and -not (Test-Path $githubDir)) {
    Write-Error "未找到 .github 目录: $githubDir"
    exit 1
}

EnsureDir $promptsDst
EnsureDir $skillsDst
# 旧路径（升级清理用），不主动创建
if (Test-Path $skillsDstOld) { Write-Host "  ⚠ 检测到旧版技能路径，安装后将自动清理" -ForegroundColor Yellow }

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
    if (-not $WhatIf) { Remove-Item -Path $manifestPath -Force -ErrorAction SilentlyContinue }
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

# Prompts
$promptFiles = @()
if (Test-Path $promptsSrc) {
    $promptFiles = @(Get-ChildItem -Path $promptsSrc -Filter "*.prompt.md" -File | Sort-Object Name)
    foreach ($f in $promptFiles) { $newAssets.Add($f.Name) }
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
    Get-ChildItem -Path $promptsDst -Filter "*.instructions.md" -File | ForEach-Object { $virtual.Add($_.Name) }
    Get-ChildItem -Path $promptsDst -Filter "*.agent.md" -File | ForEach-Object { $virtual.Add($_.Name) }
    Get-ChildItem -Path $promptsDst -Filter "*.prompt.md" -File | ForEach-Object { $virtual.Add($_.Name) }
    $oldAssets = @($virtual)
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

# 1. Skills
Write-Host "[1/5] Skills ($($skillFolders.Count))" -ForegroundColor Yellow
foreach ($folder in $skillFolders) {
    CopySkillFolder $folder
    WriteStep 'skill' $folder.Name
    $installed++
}
if ($skillFolders.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 清理旧版技能路径（%APPDATA%\Code\User\prompts\skills\ 下同名目录）
if (Test-Path $skillsDstOld) {
    $cleanedOld = 0
    foreach ($folder in $skillFolders) {
        $oldPath = Join-Path $skillsDstOld $folder.Name
        if (Test-Path $oldPath) {
            if (-not $WhatIf) { Remove-Item -Path $oldPath -Recurse -Force }
            $cleanedOld++
        }
    }
    if ($cleanedOld -gt 0) {
        Write-Host "    （旧路径清理 $cleanedOld 项）" -ForegroundColor DarkGray
    }
    # 旧目录为空则删除
    $remaining = @(Get-ChildItem -Path $skillsDstOld -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0 -and -not $WhatIf) {
        Remove-Item -Path $skillsDstOld -Force -ErrorAction SilentlyContinue
    }
}

# 2. Instructions
Write-Host "[2/5] Instructions ($($instructionFiles.Count))" -ForegroundColor Yellow
foreach ($f in $instructionFiles) {
    CopyFileAsset $f.FullName $f.Name
    WriteStep 'instr' $f.Name
    $installed++
}
if ($instructionFiles.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 3. Prompts
Write-Host "[3/5] Prompts ($($promptFiles.Count))" -ForegroundColor Yellow
foreach ($f in $promptFiles) {
    CopyFileAsset $f.FullName $f.Name
    WriteStep 'prompt' $f.Name
    $installed++
}
if ($promptFiles.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 4. Agents
Write-Host "[4/5] Agents ($($agentFiles.Count))" -ForegroundColor Yellow
foreach ($f in $agentFiles) {
    CopyFileAsset $f.FullName $f.Name
    WriteStep 'agent' $f.Name
    $installed++
}
if ($agentFiles.Count -eq 0) { Write-Host "    （空）" -ForegroundColor DarkGray }

# 5. 全局 Copilot 指令（注入 applyTo 头部）
Write-Host "[5/5] 全局 Copilot 指令" -ForegroundColor Yellow
if (Test-Path $globalInstrSrc) {
    $content = Get-Content -Path $globalInstrSrc -Raw -Encoding UTF8
    $wrapped = "---`napplyTo: `"**`"`n---`n" + $content
    $dstFile = Join-Path $promptsDst $globalInstrName
    if (-not $WhatIf) {
        [System.IO.File]::WriteAllText($dstFile, $wrapped, [System.Text.UTF8Encoding]::new($false))
    }
    WriteStep 'global' $globalInstrName
    $installed++
} else {
    Write-Host "    （跳过：$globalInstrSrc 不存在）" -ForegroundColor DarkGray
}

# ── Write Manifest ────────────────────────────────────────────────────────────
WriteManifest $newAssets

# ── 完成 ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== 安装完成 ===" -ForegroundColor Green
Write-Host "  安装/更新: $installed 项"
Write-Host "  孤儿清理: $($orphans.Count) 项"
Write-Host "  Manifest : $manifestPath"
Write-Host ""
Write-Host "重启 VS Code 后即可在所有项目中使用。"
Write-Host ""
