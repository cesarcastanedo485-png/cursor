# Runs `flutter run` with --dart-define from repo-root .env (MORDECAI_PUBLIC_URL, MORDECAI_BRIDGE_SECRET).
# Usage: cd cursor_mobile; .\run_with_repo_env.ps1
# Extra args pass through: .\run_with_repo_env.ps1 --release

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $repoRoot ".env"
$defines = [System.Collections.ArrayList]@()

function Add-Define([string]$name, [string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    $escaped = $value.Replace("'", "''")
    [void]$defines.Add("--dart-define=$name=$escaped")
}

if (Test-Path $envFile) {
    Get-Content -LiteralPath $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        switch ($key) {
            "MORDECAI_BRIDGE_SECRET" { Add-Define "MORDECAI_BRIDGE_SECRET" $val }
            "MORDECAI_PUBLIC_URL" { Add-Define "MORDECAI_BASE_URL" $val }
        }
    }
} else {
    Write-Warning "No repo .env at $envFile — run without dart-defines."
}

Push-Location $PSScriptRoot
try {
    if ($defines.Count -gt 0) {
        Write-Host "flutter run with Mordecai defines from .env ($($defines.Count) vars)"
        & flutter run @defines @args
    } else {
        & flutter run @args
    }
} finally {
    Pop-Location
}
