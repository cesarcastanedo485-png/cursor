<#
.SYNOPSIS
  One-command release flow: commit + push + build master APK.

.DESCRIPTION
  Runs from project root:
    1) git add -A
    2) git commit (if there are staged changes)
    3) git push
    4) build/copy canonical APK to Desktop via copy_apk_for_phone.ps1

  Canonical output APK:
    Desktop\MordechaiusMaximus-install.apk

.PARAMETER Message
  Commit message to use when committing changes.

.PARAMETER SkipPush
  If set, do not push to origin.

.PARAMETER KeepLegacyNames
  Passed through to copy_apk_for_phone.ps1.
#>
param(
    [string]$Message = "release: master APK update",
    [switch]$SkipPush,
    [switch]$KeepLegacyNames
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CopyScript = Join-Path $PSScriptRoot "copy_apk_for_phone.ps1"

if (-not (Test-Path $CopyScript)) {
    throw "Missing script: $CopyScript"
}

Push-Location $ProjectRoot
try {
    Write-Host "==> Preparing git changes..." -ForegroundColor Cyan
    git add -A

    $staged = git diff --cached --name-only
    if ($staged) {
        Write-Host "==> Committing changes..." -ForegroundColor Cyan
        git commit -m $Message
    } else {
        Write-Host "No staged changes to commit. Continuing..." -ForegroundColor Yellow
    }

    if (-not $SkipPush) {
        Write-Host "==> Pushing to origin..." -ForegroundColor Cyan
        git push
    } else {
        Write-Host "SkipPush enabled. Not pushing." -ForegroundColor Yellow
    }

    Write-Host "==> Building master APK..." -ForegroundColor Cyan
    if ($KeepLegacyNames) {
        & $CopyScript -Build -KeepLegacyNames
    } else {
        & $CopyScript -Build
    }
    if ($LASTEXITCODE -ne 0) {
        throw "APK build/copy failed with exit code $LASTEXITCODE"
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $apk = Join-Path $desktop "MordechaiusMaximus-install.apk"
    Write-Host ""
    Write-Host "Master release complete." -ForegroundColor Green
    Write-Host "APK: $apk" -ForegroundColor White
}
finally {
    Pop-Location
}

