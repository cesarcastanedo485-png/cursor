# Run Private AI simulation tests (ping, chat, image generation).
# These tests use a mock HTTP server to simulate Ollama/OpenAI API responses.
# Usage: .\scripts\run_private_ai_tests.ps1

Set-Location $PSScriptRoot\..

Write-Host "==> Private AI Service Tests (mock server, real HTTP)" -ForegroundColor Cyan
Write-Host "    - ping via /v1/models"
Write-Host "    - chatCompletion (send message, wait for reply)"
Write-Host "    - imageGenerations (prompt, get URL)"
Write-Host ""
flutter test test/private_ai_service_test.dart --reporter expanded

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==> Private AI Panel Widget Tests" -ForegroundColor Cyan
    Write-Host "    - 5 preset cards with Chat/Studio"
    Write-Host "    - Tapping Chat shows Connecting dialog"
    Write-Host "    - Tapping Studio shows Connecting dialog"
    Write-Host ""
    flutter test test/private_ai_panel_test.dart --reporter expanded
}

exit $LASTEXITCODE
