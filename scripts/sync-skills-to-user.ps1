# 此脚本已改名为 install-copilot-assets.ps1，本文件保留为兼容入口。
# This script has been renamed to install-copilot-assets.ps1.
param([switch]$Clean)

$newScript = Join-Path $PSScriptRoot "install-copilot-assets.ps1"
if (Test-Path $newScript) {
    & $newScript @PSBoundParameters
} else {
    Write-Error "未找到新脚本: $newScript"
}
