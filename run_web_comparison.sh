#!/bin/bash
# Automated WASM (Skwasm/WebGPU) vs CanvasKit (WebGL) benchmark comparison.
#
# This script builds the benchmark app with both web renderers and serves
# them side-by-side for easy comparison.
#
# Usage:
#   chmod +x run_web_comparison.sh
#   ./run_web_comparison.sh
#
# Prerequisites:
#   - Flutter SDK in PATH
#   - Chrome/Chromium installed (for headless or manual testing)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Web Renderer A/B Comparison ==="
echo ""

# Build with CanvasKit (WebGL)
echo "[1/4] Building with CanvasKit (WebGL)..."
flutter build web --web-renderer canvaskit --dart-define=AUTO_RUN=true \
  --release -o build/web_canvaskit 2>&1 | tail -3

# Build with Skwasm (WebGPU/Wasm)
echo "[2/4] Building with Skwasm (WebGPU + Wasm)..."
flutter build web --web-renderer skwasm --dart-define=AUTO_RUN=true \
  --release -o build/web_skwasm 2>&1 | tail -3

echo "[3/4] Builds complete."
echo ""
echo "To compare:"
echo "  1. Serve CanvasKit build:  cd build/web_canvaskit && python3 -m http.server 8080"
echo "  2. Serve Skwasm build:     cd build/web_skwasm && python3 -m http.server 8081"
echo "  3. Open http://localhost:8080 (CanvasKit/WebGL)"
echo "  4. Open http://localhost:8081 (Skwasm/WebGPU)"
echo "  5. Both will auto-run benchmarks and save JSON results"
echo "  6. Import both JSON files into either instance for comparison"
echo ""

# Optionally serve both
if command -v python3 &>/dev/null; then
  echo "[4/4] Starting servers..."
  echo "  CanvasKit (WebGL):       http://localhost:8080"
  echo "  Skwasm (WebGPU + Wasm):  http://localhost:8081"
  echo ""
  echo "Press Ctrl+C to stop both servers."
  echo ""

  python3 -m http.server 8080 --directory build/web_canvaskit &
  PID1=$!
  python3 -m http.server 8081 --directory build/web_skwasm &
  PID2=$!

  trap "kill $PID1 $PID2 2>/dev/null; exit 0" INT TERM
  wait
else
  echo "[4/4] python3 not found — serve the builds manually."
fi
