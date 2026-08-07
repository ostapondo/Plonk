#!/bin/sh
# Builds Plonk.app in the repo root.
set -eu
cd "$(dirname "$0")/.."

# One source of truth for the release number. Bump version.env, nothing else:
# MARKETING_VERSION is what people see, BUILD_NUMBER is what macOS compares when
# deciding whether a copy is newer, so it has to rise on every release.
. ./version.env

# TCC keys Accessibility and Screen Recording on the signature, so the identity
# has to be the same one every build. An ad-hoc signature is a new identity each
# time, which silently revokes both — refuse to produce a bundle like that
# rather than let it look built and then fail at the first window move. Checked
# before anything is written, so a missing identity leaves the working app alone.
IDENTITY=${PLONK_SIGN_IDENTITY:-Plonk Dev}
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
	cat >&2 <<MSG
error: code-signing identity "$IDENTITY" is not in the keychain.

Create it once, then re-run this script:
  Keychain Access > Certificate Assistant > Create a Certificate...
  Name: $IDENTITY   Identity Type: Self Signed Root   Type: Code Signing

Set PLONK_SIGN_IDENTITY to build with a different one.
MSG
	exit 1
fi

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
	<key>NSMicrophoneUsageDescription</key>
	<string>Push-to-talk voice commands listen while the key is held.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Spoken commands are transcribed on this Mac and sent to your agent.</string>
</dict>
</plist>
EOF
codesign --force --options runtime --sign "$IDENTITY" "$APP"

# A changed requirement means every permission the app holds has just been
# dropped. That is worth a line of output; discovering it from a failed capture
# is not.
REQUIREMENT=$(codesign -d -r- "$APP" 2>/dev/null | sed -n 's/^designated => //p')
STAMP=App/.build/last-designated-requirement
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" != "$REQUIREMENT" ]; then
	echo "warning: signing identity changed since the last build; macOS will ask for Accessibility and Screen Recording again" >&2
fi
mkdir -p "$(dirname "$STAMP")"
printf '%s\n' "$REQUIREMENT" > "$STAMP"

echo "built $APP"
