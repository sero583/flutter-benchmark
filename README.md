# Flutter Renderer Benchmark

A comprehensive GPU stress-test benchmark suite for comparing Flutter rendering backends.
Measures frame-time performance across **Impeller (Vulkan / Metal)** and **Skia (OpenGL / ANGLE)**
with detailed metrics, real-time resource monitoring, A/B testing, and JSON export.

Created by [Serhat Güler (@sero583)](https://github.com/sero583) for validating
the Impeller Vulkan desktop backend introduced in
[flutter/flutter#181711](https://github.com/flutter/flutter/issues/181711).

---

## Purpose

This benchmark was built to **stress-test and validate** the Flutter Impeller Vulkan
rendering backend on desktop (Windows and Linux). It exercises the GPU pipeline with
nine increasingly demanding scenes that cover particles, nested widgets, bezier
curves, image composition, text rendering, transforms, shader masks, deep opacity
trees, and non-uniform text scaling — the same workloads that exposed and helped fix
every crash, corruption, and memory issue addressed in the PR.

All nine scenes now run to completion **multiple times without any crash, corruption,
or memory leak** on both Windows (AMD Radeon RX 6750 XT, RDNA 2) and Linux.

## Features

| Feature | Details |
|---|---|
| **9 stress-test scenes** | Particle Storm, Widget Cascade, Custom Painter Heavy, Image Composition, Text Rendering, Transform & Clip, Shader Mask Matrix, Opacity Tree, Text Scale Test |
| **Real-time HUD** | FPS sparkline, avg/min/1%-low FPS, p95/p99 frame times, jank %, smoothness score |
| **Live resource monitoring** | RAM, VRAM, GPU load, GPU temperature, CPU % (NVIDIA + AMD) |
| **Adaptive warmup** | 1–5 s variance-based stabilization before measurement |
| **A/B renderer testing** | Run two renderers side-by-side and compare |
| **JSON export/import** | Save results (v3.0 format), reload, compare across machines |
| **Auto-run mode** | Headless CI execution via `--dart-define=AUTO_RUN=true` |
| **Cross-platform** | Windows, Linux, macOS, Web (CanvasKit & Skwasm) |

## Renderer Detection

The app **optionally** uses the `PlatformDispatcher.renderingBackend` API introduced
by [PR #181711](https://github.com/flutter/flutter/issues/181711). This API is
**not required** — the app compiles and runs on any Flutter SDK (>= 3.10.3).
When the getter is unavailable the renderer label shows "Undetected" and every other
feature works normally.

| Backend constant | Displayed as |
|---|---|
| `RenderingBackend.vulkan` | Impeller (Vulkan) |
| `RenderingBackend.metal` | Impeller (Metal) |
| `RenderingBackend.opengl` | Skia (OpenGL / ANGLE) |
| `RenderingBackend.software` | Software Rasterizer |
| `RenderingBackend.canvaskit` | CanvasKit (WebGL) |
| `RenderingBackend.skwasm` | Skwasm (WebGPU) |

## Requirements

- Flutter SDK >= 3.10.3
- **Optional:** A Flutter engine build with Impeller Vulkan support for
  `RenderingBackend` detection and Vulkan rendering

## Building the Custom Engine (e.g. for Vulkan)

The Impeller Vulkan desktop backend is not yet in upstream Flutter. To use it, you need
to build the engine from the PR branch.

### Linux / WSL

```bash
# 1. Clone Flutter and set up engine development
git clone https://github.com/flutter/flutter.git
cd flutter
cp engine/scripts/standard.gclient .gclient

# 2. Check out the Vulkan branch (adjust remote/branch as needed)
cd engine/src/flutter
git remote add vulkan https://github.com/sero583/flutter.git
git fetch vulkan impeller-vulkan-desktop
git checkout vulkan/impeller-vulkan-desktop
cd ../../..

# 3. Sync dependencies (~20 GB, adjust -j for parallelism)
gclient sync --no-history -j4

# 4. Generate build files and build
cd engine/src
flutter/tools/gn --unoptimized
ninja -C out/host_debug_unopt       # add -jN for parallel builds (e.g. -j8 for 8 CPU cores)
```

### Windows

```powershell
# 1. Same clone / branch / sync steps as above

# 2. Set toolchain variable (required if you're not using Google's internal toolchain)
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"

# 3. Generate and build
cd engine\src
python3 flutter\tools\gn --unoptimized
ninja -C out\host_debug_unopt       # add -jN for parallel builds (e.g. -j8 for 8 CPU cores)
```

> **What is `-j`?** The `-j` flag tells `ninja` how many build tasks to run in
> parallel. Higher values speed up the build but use more RAM (~1–2 GB per task).
> A reasonable default is `-j` followed by the number of CPU cores on your machine
> (e.g. `-j8` for an 8-core CPU). Omitting `-j` lets ninja auto-detect.

For detailed engine setup, see
[Setting up the Engine development environment](https://github.com/flutter/flutter/blob/main/docs/engine/contributing/Setting-up-the-Engine-development-environment.md).

## Running

### Default renderer (Skia / OpenGL)

```bash
flutter run -d linux      # Linux
flutter run -d windows    # Windows
flutter run -d macos      # macOS
```

### Impeller (Vulkan) — requires custom engine build

```bash
# Linux
flutter run -d linux \
  --local-engine=host_debug_unopt \
  --local-engine-host=host_debug_unopt \
  --local-engine-src-path=/path/to/engine/src \
  --enable-impeller \
  --dart-define=FLUTTER_ENGINE_SWITCHES=--impeller-backend=vulkan
```

```powershell
# Windows
flutter run -d windows `
  --local-engine=host_debug_unopt `
  --local-engine-host=host_debug_unopt `
  --local-engine-src-path=C:\path\to\engine\src `
  --enable-impeller `
  --dart-define=FLUTTER_ENGINE_SWITCHES=--impeller-backend=vulkan
```

For pre-built executables (not using `flutter run`), set environment variables instead:

```bash
# Linux / macOS
export FLUTTER_ENGINE_SWITCHES="2"
export FLUTTER_ENGINE_SWITCH_1="enable-impeller=true"
export FLUTTER_ENGINE_SWITCH_2="impeller-backend=vulkan"
./your_flutter_app
```

```powershell
# Windows
$env:FLUTTER_ENGINE_SWITCHES = "2"
$env:FLUTTER_ENGINE_SWITCH_1 = "enable-impeller=true"
$env:FLUTTER_ENGINE_SWITCH_2 = "impeller-backend=vulkan"
.\your_flutter_app.exe
```

### Auto-run mode (headless, for CI)

Auto-run mode runs all 9 scenes sequentially without user interaction and saves
results as JSON. Pass `AUTO_RUN=true` as a compile-time define:

```bash
# Linux — saves results to the specified path
AUTO_BENCH_OUTPUT=/tmp/results.json flutter run -d linux --dart-define=AUTO_RUN=true

# Windows — same, with custom engine
$env:AUTO_BENCH_OUTPUT = "C:\temp\results.json"
flutter run -d windows --dart-define=AUTO_RUN=true `
  --local-engine=host_debug_unopt --local-engine-src-path=path\to\engine\src `
  --local-engine-host=host_debug_unopt
```

### Web

```bash
# Build with CanvasKit (WebGL)
flutter build web --web-renderer canvaskit

# Serve with the included tool (sets required COOP/COEP headers for Skwasm)
dart run tool/serve.dart 8080 build/web
```

### Web A/B comparison

Two helper scripts automate building and serving both web renderers side-by-side:

- **`build_web_all.ps1`** (Windows/PowerShell) — builds CanvasKit and Skwasm variants,
  generates a landing page, and optionally starts a local server
- **`run_web_comparison.sh`** (Linux/macOS) — builds both variants with auto-run enabled
  and serves them on ports 8080/8081 for easy comparison 

```powershell
# Windows
.\build_web_all.ps1 -Serve
.\run_web_comparison.ps1

# Linux / macOS
./build_web_all.sh --serve
./run_web_comparison.sh
```

### Included tools

| File | Purpose |
|---|---|
| `tool/serve.dart` | Lightweight HTTP server with COOP/COEP headers required by Skwasm (WebGPU) builds |
| `build_web_all.ps1` | PowerShell: build CanvasKit + Skwasm web variants with a landing page |
| `build_web_all.sh` | Bash: same as above, for Linux / macOS |
| `run_web_comparison.ps1` | PowerShell: A/B web renderer comparison with side-by-side servers |
| `run_web_comparison.sh` | Bash: same as above, for Linux / macOS |

## Benchmark Scenes

| # | Scene | What it tests | Duration |
|---|---|---|---|
| 1 | **Particle Storm** | 10 000 particles with physics and blending | 15 s |
| 2 | **Widget Cascade** | 500 animated, nested, shadowed widgets | 15 s |
| 3 | **Custom Painter Heavy** | 2 000 bezier curves with gradient fills per frame | 15 s |
| 4 | **Image Composition** | 200 overlapping gradient orbs with opacity animation | 15 s |
| 5 | **Text Rendering** | 1 000 text spans with varying fonts and shadows | 15 s |
| 6 | **Transform & Clip** | 300 rotated, scaled, clipped containers per frame | 15 s |
| 7 | **Shader Mask Matrix** | 8 × 8 grid of shader-masked animated gradients | 15 s |
| 8 | **Opacity Tree** | 20-level deep nested opacity + color filter tree | 15 s |
| 9 | **Text Scale Test** | Non-uniform `Transform.scale` text ([#182143](https://github.com/flutter/flutter/issues/182143)) | 20 s |

## Metrics Collected

- **Average / Min / Max FPS**, 1 % Low FPS
- **p95 / p99 frame times** (ms), standard deviation
- **Jank count & percentage** — frames exceeding one vsync interval (adapts to display Hz)
- **Smoothness score** — composite quality metric (0–100)
- **RAM** (Dart RSS + system), **VRAM**, **GPU load**, **GPU temperature**, **CPU %**

## Test Results

All nine benchmark scenes pass on:

| Platform | GPU | Renderer | Result |
|---|---|---|---|
| Windows 10 Pro | AMD Radeon RX 6750 XT (RDNA 2, 12 GB) | Impeller (Vulkan) | **PASS** — stable, no crashes, multiple runs |
| Windows 10 Pro | AMD Radeon RX 6750 XT | Skia (OpenGL / ANGLE) | **PASS** — baseline, no regressions |
| WSL 2 Ubuntu 24.04 | Mesa dzn (D3D12 via WSLg) | Impeller (Vulkan) | **PASS** — all 9 scenes, zero errors |
| WSL 2 Ubuntu 24.04 | Mesa / WSLg | Skia (OpenGL) | **PASS** — baseline |
| Android 15 (API 35) | Samsung Xclipse 940 (Galaxy S24) | Impeller (Vulkan) | **PARTIAL** — most scenes pass; extreme stress tests (10k particles) can trigger OOM on mobile SoCs (not a regression — same on upstream engine) |

## License

MIT — see [LICENSE](LICENSE).
