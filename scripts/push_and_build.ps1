param(
    [string]$Message = "Update WonderPlay Arcade"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Staging all changes..." -ForegroundColor Cyan
git add .

$status = git status --porcelain
if (-not $status) {
    Write-Host "No new file changes to commit. Triggering GitHub Actions APK build directly..." -ForegroundColor Yellow
    gh workflow run build-apk.yml
    gh run list --workflow=build-apk.yml --limit 1
    exit 0
}

Write-Host "==> Committing with message: '$Message'..." -ForegroundColor Cyan
git commit -m "$Message"

Write-Host "==> Pushing to origin/main (triggers GitHub Actions APK build)..." -ForegroundColor Cyan
git push origin main

Write-Host "==> Pipeline triggered! View runs at: https://github.com/viswajithcn/wonderplay-arcade/actions" -ForegroundColor Green
