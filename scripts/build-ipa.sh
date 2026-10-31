#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

echo "Generating Xcode project…"
xcodegen generate

echo "Building unsigned Release app…"
rm -rf build Payload Nova.ipa

BUILD_SETTINGS=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  DEVELOPMENT_TEAM=""
)

if [ -n "${NOVA_API_BASE_URL:-}" ]; then
  BUILD_SETTINGS+=("NOVA_API_BASE_URL=${NOVA_API_BASE_URL}")
fi

xcodebuild \
  -project Nova.xcodeproj \
  -scheme Nova \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  "${BUILD_SETTINGS[@]}" \
  build

APP_PATH="build/Build/Products/Release-iphoneos/Nova.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Build did not produce $APP_PATH" >&2
  exit 1
fi

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry Nova.ipa Payload
rm -rf Payload

echo "Built Nova.ipa ($(du -h Nova.ipa | cut -f1))"
