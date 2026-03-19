<#
.SYNOPSIS
  Copies the RELEASE Android APK to your Desktop with a clear name for phone install (Drive, USB, etc.).

.DESCRIPTION
  The installable app is ONLY:
    build\app\outputs\flutter-apk\app-release.apk

  Do NOT upload .code-workspace files — those are Cursor/VS Code project files, not apps.

  Default output: Desktop\MordechaiusMaximus-install.apk

.PARAMETER Build
  Run `flutter build apk --release` first (needs ANDROID_HOME and Flutter on PATH).

.PARAMETER Destination
  Full path for the copied file (default: Desktop\MordechaiusMaximus-install.apk).
#>
param(
    [switch]$Build,
    [string]$Destination = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ApkSource = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"

if ($Build) {
    if (-not $env:ANDROID_HOME) {
        $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }
    $flutter = "flutter"
    if (Test-Path "C:\Users\cmc\flutter\bin\flutter.bat") {
        $flutter = "C:\Users\cmc\flutter\bin\flutter.bat"
    }
    Write-Host "Building release APK..." -ForegroundColor Cyan
    Push-Location $ProjectRoot
    try {
        & $flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $ApkSource)) {
    Write-Host ""
    Write-Host "APK not found at:" -ForegroundColor Red
    Write-Host "  $ApkSource" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run from project root:" -ForegroundColor Cyan
    Write-Host "  flutter build apk --release" -ForegroundColor White
    Write-Host "Or run this script with -Build:" -ForegroundColor Cyan
    Write-Host "  .\scripts\copy_apk_for_phone.ps1 -Build" -ForegroundColor White
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $Destination = Join-Path $desktop "MordechaiusMaximus-install.apk"
}

Copy-Item -Path $ApkSource -Destination $Destination -Force
$sizeMb = [math]::Round((Get-Item $Destination).Length / 1MB, 2)

Write-Host ""
Write-Host "Copied installable APK to:" -ForegroundColor Green
Write-Host "  $Destination" -ForegroundColor White
Write-Host "  ($sizeMb MB) - file type must be .apk, NOT .code-workspace" -ForegroundColor Gray
Write-Host ""
Write-Host "Next: Upload this .apk to Google Drive (drive.google.com), then on your phone:" -ForegroundColor Cyan
Write-Host "  Drive app -> find the file -> three dots -> Download -> open from Files/Downloads -> Install" -ForegroundColor Gray
Write-Host "  See INSTALL_ON_PHONE.md for full steps." -ForegroundColor Gray
Write-Host ""
