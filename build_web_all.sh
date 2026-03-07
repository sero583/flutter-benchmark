#!/bin/bash
# Flutter Renderer Benchmark — Web Build Script (Linux / macOS)
# Builds CanvasKit and Skwasm variants, then creates a landing page.
#
# Usage:
#   chmod +x build_web_all.sh
#   ./build_web_all.sh              # build both
#   ./build_web_all.sh --serve      # build both and start local server
#   ./build_web_all.sh --skip-skwasm        # build CanvasKit only
#   ./build_web_all.sh --skip-canvaskit     # build Skwasm only

set -e

FLUTTER="${FLUTTER:-flutter}"
OUTPUT_DIR="build/web_benchmark"
SKIP_CANVASKIT=false
SKIP_SKWASM=false
SERVE=false

for arg in "$@"; do
  case "$arg" in
    --skip-canvaskit) SKIP_CANVASKIT=true ;;
    --skip-skwasm)    SKIP_SKWASM=true ;;
    --serve)          SERVE=true ;;
    *)                echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

echo ""
echo "  Flutter Renderer Benchmark — Web Builder"
echo "  ========================================="
echo ""

# Clean previous build
if [ -d "$OUTPUT_DIR" ]; then
  echo "  Cleaning previous build..."
  rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

step=0
total=3
$SKIP_CANVASKIT && total=$((total - 1))
$SKIP_SKWASM && total=$((total - 1))

# — Build CanvasKit —
if ! $SKIP_CANVASKIT; then
  step=$((step + 1))
  echo "  [$step/$total] Building CanvasKit (WebGL)..."
  if $FLUTTER build web 2>&1 | tail -3 && [ -f "build/web/index.html" ]; then
    mkdir -p "$OUTPUT_DIR/canvaskit"
    cp -r build/web/* "$OUTPUT_DIR/canvaskit/"
    echo "       OK  — CanvasKit build complete"
  else
    echo "       FAIL — CanvasKit build failed"
  fi
fi

# — Build Skwasm —
if ! $SKIP_SKWASM; then
  step=$((step + 1))
  echo "  [$step/$total] Building Skwasm (WebAssembly)..."
  if $FLUTTER build web --wasm 2>&1 | tail -3 && [ -f "build/web/index.html" ]; then
    mkdir -p "$OUTPUT_DIR/skwasm"
    cp -r build/web/* "$OUTPUT_DIR/skwasm/"
    echo "       OK  — Skwasm build complete"
  else
    echo "       FAIL — Skwasm build failed"
  fi
fi

# — Landing page —
step=$((step + 1))
echo "  [$step/$total] Generating landing page..."
if [ -f "web/landing.html" ]; then
  cp "web/landing.html" "$OUTPUT_DIR/index.html"
  echo "       OK  — Landing page ready"
else
  echo "       SKIP — web/landing.html not found"
fi

# — Summary —
echo ""
echo "  Build complete!"
echo "  Output: $OUTPUT_DIR/"
echo ""

[ -f "$OUTPUT_DIR/canvaskit/index.html" ] && echo "    CanvasKit : $OUTPUT_DIR/canvaskit/index.html"
[ -f "$OUTPUT_DIR/skwasm/index.html" ]    && echo "    Skwasm    : $OUTPUT_DIR/skwasm/index.html"
[ -f "$OUTPUT_DIR/index.html" ]           && echo "    Landing   : $OUTPUT_DIR/index.html"

echo ""
echo "  To serve locally:"
echo "    dart run tool/serve.dart 8080 $OUTPUT_DIR"
echo ""

# — Optional: auto-serve —
if $SERVE; then
  echo "  Starting local server..."
  dart run tool/serve.dart 8080 "$OUTPUT_DIR"
fi
