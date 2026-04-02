param(
    [string]$Source = (Join-Path $PSScriptRoot "..\.github\skills"),
    [string]$Destination = (Join-Path $HOME ".copilot\skills"),
    [switch]$Clean
)

$sourcePath = (Resolve-Path $Source).Path

if (-not (Test-Path $sourcePath)) {
    throw "Source skills folder not found: $Source"
}

if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$skillFolders = Get-ChildItem -Path $sourcePath -Directory

foreach ($folder in $skillFolders) {
    $target = Join-Path $Destination $folder.Name

    if ($Clean -and (Test-Path $target)) {
        Remove-Item -Path $target -Recurse -Force
    }

    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }

    Copy-Item -Path (Join-Path $folder.FullName "*") -Destination $target -Recurse -Force
    Write-Host "Synced skill: $($folder.Name) -> $target"
}

Write-Host "Done. Skills synced to $Destination"
