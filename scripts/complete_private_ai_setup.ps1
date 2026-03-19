# Run after Ollama is installed (finish SETUP_PRIVATE_AIs.md Ollama steps).
# Usage: .\scripts\complete_private_ai_setup.ps1
# Optional: -Skip72b to pull a smaller model first (qwen2.5:7b)

param([switch]$Skip72b)

$ErrorActionPreference = "Continue"

function Find-Ollama {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
        "C:\Program Files\Ollama\ollama.exe",
        "C:\Program Files (x86)\Ollama\ollama.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$ollama = Find-Ollama
if (-not $ollama) {
    Write-Host "Ollama CLI not found. Install from https://ollama.com/download or run:" -ForegroundColor Yellow
    Write-Host "  winget install Ollama.Ollama" -ForegroundColor Cyan
    Write-Host "Then open a NEW terminal and run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Using: $ollama" -ForegroundColor Green

# Listen on LAN (phone access) - set for current session; add user env OLLAMA_HOST for permanent
$env:OLLAMA_HOST = "0.0.0.0:11434"
Write-Host "OLLAMA_HOST=0.0.0.0:11434 (this session). Add user env var OLLAMA_HOST for permanent LAN access." -ForegroundColor Gray

if ($Skip72b) {
    Write-Host "`nPulling qwen2.5:7b (smaller)..." -ForegroundColor Cyan
    & $ollama pull qwen2.5:7b
} else {
    Write-Host "`nPulling qwen3.5:72b (large download, may take 30+ min)..." -ForegroundColor Cyan
    & $ollama pull qwen3.5:72b
    if ($LASTEXITCODE -ne 0) {
        Write-Host "qwen3.5:72b failed - trying qwen2.5:72b..." -ForegroundColor Yellow
        & $ollama pull qwen2.5:72b
    }
}

Write-Host "`nPulling FLUX Klein (may fail if name changed on registry)..." -ForegroundColor Cyan
& $ollama pull x/flux2-klein
if ($LASTEXITCODE -ne 0) {
    Write-Host "x/flux2-klein not found - check ollama.com library for current FLUX model names." -ForegroundColor Yellow
}

Write-Host "`nDone. Start Ollama app if needed. ComfyUI: cd C:\Users\cmc\ComfyUI; python main.py --listen 0.0.0.0 --port 8188" -ForegroundColor Green
