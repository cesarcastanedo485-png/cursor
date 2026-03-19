<#
.SYNOPSIS
  Runs Mordechaius Maximus on a connected Android emulator or device (after you start the AVD in Android Studio).

.DESCRIPTION
  Waits briefly for adb to show a device, then runs `flutter run`.
  Start the emulator first: Android Studio -> Device Manager -> Play on your AVD.

.EXAMPLE
  .\scripts\run_on_emulator.ps1
#>
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$flutter = "C:\Users\cmc\flutter\bin\flutter.bat"
if (-not (Test-Path $flutter)) { $flutter = "flutter" }

Write-Host "Waiting for Android device (start emulator in Android Studio if needed)..." -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(2)
$found = $false
while ((Get-Date) -lt $deadline) {
    if (Test-Path $adb) {
        $lines = @(& $adb devices 2>&1 | Where-Object { $_ -match "\S+\s+device$" })
        if ($lines.Length -gt 0) {
            $found = $true
            break
        }
    }
    Start-Sleep -Seconds 2
}

if (-not $found) {
    Write-Host ""
    Write-Host "No Android device detected. Do this:" -ForegroundColor Yellow
    Write-Host "  1. Android Studio -> Device Manager -> start your AVD (Play)." -ForegroundColor White
    Write-Host "  2. Run this script again, or: cd $ProjectRoot ; flutter run" -ForegroundColor White
    Write-Host ""
    exit 1
}

Push-Location $ProjectRoot
try {
    & $flutter run
} finally {
    Pop-Location
}
