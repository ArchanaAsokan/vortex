#!/usr/bin/env bash
# build_app.sh — builds Vortex in Release mode and opens it directly
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
APP_NAME="Vortex"
SCHEME="Vortex"
PROJECT="Vortex.xcodeproj"
CONFIGURATION="Release"
RELEASE_DIR="$(cd "$(dirname "$0")/.." && pwd)/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"

# ── Helpers ──────────────────────────────────────────────────────────────────
step() { echo; echo "▶ $*"; }
die()  { echo "✗ $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
step "Checking prerequisites"
command -v xcodebuild >/dev/null || die "Xcode command-line tools not found. Run: xcode-select --install"

cd "$(dirname "$0")/.."

# ── Build ────────────────────────────────────────────────────────────────────
step "Building $APP_NAME ($CONFIGURATION)"
BUILD_DIR="$(mktemp -d)"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${BUILD_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  build \
  | grep -E "^(Build|CompileSwift|error:|warning:)" || true

APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
[[ -d "${APP_PATH}" ]] || die "Build succeeded but ${APP_NAME}.app not found at ${APP_PATH}"

# ── Copy to release/ ─────────────────────────────────────────────────────────
step "Copying to $RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
rm -rf "$APP_BUNDLE"
cp -R "$APP_PATH" "$APP_BUNDLE"
rm -rf "$BUILD_DIR"

echo "  Built: $APP_BUNDLE"

echo
echo "✓ Done. To launch: open \"$APP_BUNDLE\""
