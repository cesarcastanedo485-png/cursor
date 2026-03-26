# Add Flutter to PATH for this terminal session, then you can use: flutter doctor, flutter pub get, flutter run
$env:Path = "C:\Users\cmc\flutter\bin;" + $env:Path
Write-Host "Flutter added to PATH for this session. You can now run: flutter doctor, flutter pub get, flutter run" -ForegroundColor Green
# Optional: run these automatically
Set-Location $PSScriptRoot
flutter pub get
Write-Host "`nRun 'flutter run' to start the app (connect your Android phone with USB debugging first)." -ForegroundColor Cyan
Write-Host "For phone install via Drive: run .\scripts\copy_apk_for_phone.ps1 (copies .apk to Desktop — NOT .code-workspace)." -ForegroundColor DarkGray
