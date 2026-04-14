#!/usr/bin/env bash
# build-dmg.sh — builds Vortex in Release mode and packages it as a DMG
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
APP_NAME="Vortex"
SCHEME="Vortex"
PROJECT="Vortex.xcodeproj"
CONFIGURATION="Release"
DMG_NAME="${APP_NAME}.dmg"
STAGING_DIR="$(mktemp -d)"
OUTPUT_DIR="$(pwd)/dist"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "  $*"; }
step()  { echo; echo "▶ $*"; }
die()   { echo "✗ $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
step "Checking prerequisites"
command -v xcodebuild >/dev/null || die "Xcode command-line tools not found. Run: xcode-select --install"
command -v hdiutil    >/dev/null || die "hdiutil not found (should be built into macOS)"

# ── Build ────────────────────────────────────────────────────────────────────
step "Building ${APP_NAME} (${CONFIGURATION})"
BUILD_DIR="$(mktemp -d)"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${BUILD_DIR}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  clean build \
  | grep -E "^(Build|CompileSwift|error:|warning:|✓)" || true

APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
[[ -d "${APP_PATH}" ]] || die "Build succeeded but ${APP_NAME}.app not found at ${APP_PATH}"
info "Built: ${APP_PATH}"

# ── Stage ────────────────────────────────────────────────────────────────────
step "Staging DMG contents"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
# Symlink to /Applications so users can drag-install
ln -s /Applications "${STAGING_DIR}/Applications"
info "Staged to: ${STAGING_DIR}"

# ── Create DMG ───────────────────────────────────────────────────────────────
step "Creating DMG"
mkdir -p "${OUTPUT_DIR}"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

# Remove stale DMG if present
[[ -f "${DMG_PATH}" ]] && rm "${DMG_PATH}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "${DMG_PATH}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "${STAGING_DIR}" "${BUILD_DIR}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "✓ DMG ready: ${DMG_PATH}"
echo "  Open with: open \"${DMG_PATH}\""
