<#
.SYNOPSIS
  Centralized release: commit + push to trigger APK workflow (GitHub Actions).
  Works for cursor_mobile and other Flutter repos that call the reusable workflow.

.DESCRIPTION
  Runs from any workspace:
    1) cd to RepoPath
    2) Validate git repo, remote, workflow exists
    3) git add -A
    4) git commit (if there are staged changes)
    5) git push

  No local build — push triggers the GitHub Actions workflow (build APK, release, optionally Drive).
  cursor_mobile: full flow (GitHub + Drive). Other repos: GitHub-only.

.PARAMETER RepoPath
  Target repo root (e.g. C:\Users\cmc\3d-player). Default: cursor_mobile parent of this script.

.PARAMETER AppName
  Display name for releases (e.g. "3d Player"). Optional; used for reporting only.

.PARAMETER Message
  Commit message when committing changes.

.PARAMETER SkipPush
  If set, do not push to origin (useful for dry-run).
#>
param(
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
    [string]$AppName = "",
    [string]$Message = "release: APK update",
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"

$RepoPath = $RepoPath.TrimEnd('\', '/')
if (-not (Test-Path $RepoPath)) {
    throw "Repo path does not exist: $RepoPath"
}

$WorkflowPath = Join-Path $RepoPath ".github\workflows\apk_to_drive.yml"
$WorkflowPathAlt = Join-Path $RepoPath ".github\workflows\apk_to_github.yml"

$hasWorkflow = (Test-Path $WorkflowPath) -or (Test-Path $WorkflowPathAlt)
if (-not $hasWorkflow) {
    throw "No APK workflow found at .github/workflows/apk_to_drive.yml or apk_to_github.yml. Add a workflow that calls the reusable one (see plan)."
}

Push-Location $RepoPath
try {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if (-not $gitRoot) {
        throw "Not a git repository: $RepoPath"
    }

    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        throw "No remote 'origin' configured. Run: git remote add origin <url>"
    }

    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) {
        throw "Could not determine current branch."
    }

    Write-Host "==> Repo: $RepoPath" -ForegroundColor Cyan
    Write-Host "==> Branch: $branch" -ForegroundColor Cyan
    if ($AppName) { Write-Host "==> App: $AppName" -ForegroundColor Cyan }
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

    Write-Host ""
    Write-Host "Release triggered." -ForegroundColor Green
    Write-Host "Workflow will build APK and create GitHub Release." -ForegroundColor White
    $folderName = Split-Path -Leaf $RepoPath
    if ($folderName -eq "cursor_mobile") {
        Write-Host "cursor_mobile: APK will also upload to Drive. Check Drive or app 'Check for updates'." -ForegroundColor White
    } else {
        Write-Host "Other repo: Download APK from GitHub Releases (GitHub app on phone)." -ForegroundColor White
    }
}
finally {
    Pop-Location
}
