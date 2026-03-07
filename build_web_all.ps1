# Flutter Renderer Benchmark — Web Build Script
# Builds CanvasKit and Skwasm variants, then creates a landing page.

param(
    [string]$Flutter = "C:\Users\serha\flutter\bin\flutter.bat",
    [string]$OutputDir = "build\web_benchmark",
    [switch]$SkipCanvasKit,
    [switch]$SkipSkwasm,
    [switch]$Serve
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "  Flutter Renderer Benchmark — Web Builder" -ForegroundColor Cyan
Write-Host "  =========================================" -ForegroundColor DarkCyan
Write-Host ""

# Clean previous build
if (Test-Path $OutputDir) {
    Write-Host "  Cleaning previous build..." -ForegroundColor DarkGray
    Remove-Item -Recurse -Force $OutputDir
}
New-Item -ItemType Directory -Force $OutputDir | Out-Null

$step = 0
$total = 3 - [int]$SkipCanvasKit - [int]$SkipSkwasm

# ── Build CanvasKit ─────────────────────────────────────
if (-not $SkipCanvasKit) {
    $step++
    Write-Host "  [$step/$total] Building CanvasKit (WebGL)..." -ForegroundColor Yellow
    $buildOutput = & $Flutter build web 2>&1
    if (Test-Path "build\web\index.html") {
        New-Item -ItemType Directory -Force "$OutputDir\canvaskit" | Out-Null
        Get-ChildItem "build\web" | Copy-Item -Destination "$OutputDir\canvaskit" -Recurse -Force
        Write-Host "       OK  — CanvasKit build complete" -ForegroundColor Green
    } else {
        Write-Host "       FAIL — CanvasKit build failed" -ForegroundColor Red
        Write-Host $buildOutput -ForegroundColor DarkRed
    }
}

# ── Build Skwasm ────────────────────────────────────────
if (-not $SkipSkwasm) {
    $step++
    Write-Host "  [$step/$total] Building Skwasm (WebAssembly)..." -ForegroundColor Yellow
    $buildOutput = & $Flutter build web --wasm 2>&1
    if (Test-Path "build\web\index.html") {
        New-Item -ItemType Directory -Force "$OutputDir\skwasm" | Out-Null
        Get-ChildItem "build\web" | Copy-Item -Destination "$OutputDir\skwasm" -Recurse -Force
        Write-Host "       OK  — Skwasm build complete" -ForegroundColor Green
    } else {
        Write-Host "       FAIL — Skwasm build failed" -ForegroundColor Red
        Write-Host $buildOutput -ForegroundColor DarkRed
    }
}

# ── Landing page ────────────────────────────────────────
$step++
Write-Host "  [$step/$total] Generating landing page..." -ForegroundColor Yellow
if (Test-Path "web\landing.html") {
    Copy-Item "web\landing.html" "$OutputDir\index.html"
    Write-Host "       OK  — Landing page ready" -ForegroundColor Green
} else {
    Write-Host "       SKIP — web\landing.html not found" -ForegroundColor DarkYellow
}

# ── Summary ─────────────────────────────────────────────
Write-Host ""
Write-Host "  Build complete!" -ForegroundColor Cyan
Write-Host "  Output: $OutputDir\" -ForegroundColor Gray
Write-Host ""

$canvaskitExists = Test-Path "$OutputDir\canvaskit\index.html"
$skwasmExists = Test-Path "$OutputDir\skwasm\index.html"
$landingExists = Test-Path "$OutputDir\index.html"

if ($landingExists) { Write-Host "    Landing page : $OutputDir\index.html" -ForegroundColor DarkCyan }
if ($canvaskitExists) { Write-Host "    CanvasKit    : $OutputDir\canvaskit\index.html" -ForegroundColor DarkCyan }
if ($skwasmExists) { Write-Host "    Skwasm       : $OutputDir\skwasm\index.html" -ForegroundColor DarkCyan }

Write-Host ""
Write-Host "  To serve locally:" -ForegroundColor Gray
Write-Host "    dart run tool\serve.dart 8080 $OutputDir" -ForegroundColor DarkGray
Write-Host "    npx serve $OutputDir" -ForegroundColor DarkGray
Write-Host ""

# ── Optional: auto-serve ────────────────────────────────
if ($Serve) {
    Write-Host "  Starting local server..." -ForegroundColor Yellow
    dart run tool\serve.dart 8080 $OutputDir
}
