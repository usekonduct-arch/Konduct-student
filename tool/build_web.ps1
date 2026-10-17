# Builds the student web app (PWA) into build/web, ready to deploy as a static site.
#   ./tool/build_web.ps1                         against the Render backend
#   ./tool/build_web.ps1 -Demo                   demo mode, no Firebase (for trying it out)
#   $env:FCM_VAPID_KEY = '...'; ./tool/build_web.ps1   with the project's own Web Push key
# A local build, to try it out. Vercel builds the site itself from GitHub (vercel.json, tool/vercel_build.sh).
param(
  [string]$BackendUrl = 'https://konduct-backend.onrender.com',
  [switch]$Demo
)
$ErrorActionPreference = 'Stop'
$flutter = 'C:\flutter\src\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }
Set-Location (Join-Path $PSScriptRoot '..')

$defines = @("--dart-define=BACKEND_URL=$BackendUrl")
if ($env:FCM_VAPID_KEY) { $defines += "--dart-define=FCM_VAPID_KEY=$env:FCM_VAPID_KEY" }
if ($Demo) { $defines = @('--dart-define=KONDUCT_DEMO=true') }

& $flutter build web --release --no-source-maps --no-wasm-dry-run @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Flutter's own offline-first worker is replaced by web/sw.js; don't ship it.
Remove-Item build\web\flutter_service_worker.js -ErrorAction SilentlyContinue
Write-Host "Built build/web"
