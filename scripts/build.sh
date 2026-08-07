#!/bin/sh
# Builds Plonk.app in the repo root.
set -eu
cd "$(dirname "$0")/.."

# One source of truth for the release number. Bump version.env, nothing else:
# MARKETING_VERSION is what people see, BUILD_NUMBER is what macOS compares when
# deciding whether a copy is newer, so it has to rise on every release.
. ./version.env

(cd App && swift build -c release)

APP=Plonk.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp App/.build/release/plonk "$APP/Contents/MacOS/plonk"
[ -f App/Resources/AppIcon.icns ] || swift scripts/make-icon.swift
cp App/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>plonk</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>dev.plonk.app</string>
	<key>CFBundleName</key>
	<string>Plonk</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$MARKETING_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF
# Sign with a stable identity when one exists: an ad-hoc signature changes
# every build, which makes macOS drop the app's Accessibility permission.
IDENTITY=${PLONK_SIGN_IDENTITY:-Plonk Dev}
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
	codesign --force --options runtime --sign "$IDENTITY" "$APP"
else
	echo "warning: signing identity \"$IDENTITY\" not found, falling back to ad-hoc" >&2
	codesign --force --sign - "$APP"
fi
echo "built $APP"
