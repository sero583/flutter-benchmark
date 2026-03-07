# Automated WASM (Skwasm/WebGPU) vs CanvasKit (WebGL) benchmark comparison.
#
# This script builds the benchmark app with both web renderers and serves
# them side-by-side for easy comparison.
#
# Usage:
#   .\run_web_comparison.ps1
#
# Prerequisites:
#   - Flutter SDK in PATH
#   - A web browser for viewing results

param(
    [string]$Flutter = "flutter",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "  === Web Renderer A/B Comparison ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipBuild) {
    # Build with CanvasKit (WebGL)
    Write-Host "  [1/4] Building with CanvasKit (WebGL)..." -ForegroundColor Yellow
    $buildOutput = & $Flutter build web --web-renderer canvaskit --dart-define=AUTO_RUN=true --release -o build/web_canvaskit 2>&1
    if (Test-Path "build/web_canvaskit/index.html") {
        Write-Host "       OK  — CanvasKit build complete" -ForegroundColor Green
    } else {
        Write-Host "       FAIL — CanvasKit build failed" -ForegroundColor Red
        Write-Host ($buildOutput | Select-Object -Last 5) -ForegroundColor DarkRed
    }

    # Build with Skwasm (WebGPU/Wasm)
    Write-Host "  [2/4] Building with Skwasm (WebGPU + Wasm)..." -ForegroundColor Yellow
    $buildOutput = & $Flutter build web --wasm --dart-define=AUTO_RUN=true --release -o build/web_skwasm 2>&1
    if (Test-Path "build/web_skwasm/index.html") {
        Write-Host "       OK  — Skwasm build complete" -ForegroundColor Green
    } else {
        Write-Host "       FAIL — Skwasm build failed" -ForegroundColor Red
        Write-Host ($buildOutput | Select-Object -Last 5) -ForegroundColor DarkRed
    }

    Write-Host "  [3/4] Builds complete." -ForegroundColor Green
} else {
    Write-Host "  Skipping builds (--SkipBuild)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  To compare:" -ForegroundColor Gray
Write-Host "    1. CanvasKit (WebGL):  http://localhost:8080" -ForegroundColor DarkCyan
Write-Host "    2. Skwasm (WebGPU):    http://localhost:8081" -ForegroundColor DarkCyan
Write-Host "    3. Both auto-run benchmarks and save JSON results" -ForegroundColor Gray
Write-Host "    4. Import both JSON files into either instance for comparison" -ForegroundColor Gray
Write-Host ""

# Serve both variants
$canvaskitExists = Test-Path "build/web_canvaskit/index.html"
$skwasmExists = Test-Path "build/web_skwasm/index.html"

if ($canvaskitExists -or $skwasmExists) {
    Write-Host "  [4/4] Starting servers..." -ForegroundColor Yellow
    $jobs = @()

    if ($canvaskitExists) {
        Write-Host "    CanvasKit (WebGL):       http://localhost:8080" -ForegroundColor DarkCyan
        $jobs += Start-Job -ScriptBlock {
            param($dir)
            Set-Location $dir
            dart run tool/serve.dart 8080 build/web_canvaskit
        } -ArgumentList (Get-Location).Path
    }

    if ($skwasmExists) {
        Write-Host "    Skwasm (WebGPU + Wasm):  http://localhost:8081" -ForegroundColor DarkCyan
        $jobs += Start-Job -ScriptBlock {
            param($dir)
            Set-Location $dir
            dart run tool/serve.dart 8081 build/web_skwasm
        } -ArgumentList (Get-Location).Path
    }

    Write-Host ""
    Write-Host "  Press Ctrl+C to stop servers." -ForegroundColor Gray
    Write-Host ""

    try {
        while ($true) { Start-Sleep -Seconds 1 }
    } finally {
        $jobs | Stop-Job -PassThru | Remove-Job
    }
} else {
    Write-Host "  [4/4] No builds found — run without -SkipBuild first." -ForegroundColor DarkYellow
}
