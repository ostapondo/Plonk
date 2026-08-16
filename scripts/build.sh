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
IDENTITY=${PLONK_SIGN_IDENTITY:-Plonk Signing}
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
	cat >&2 <<MSG
error: code-signing identity "$IDENTITY" is not in the keychain.

If you have the .p12, import it and trust it as a root — an untrusted one is
not a *valid* identity and will not be found:
  security import plonk-signing.p12 -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cert.pem

If no identity exists yet, ./scripts/make-signing-cert.sh creates one. Do not
run it to work around this message: a different certificate is a different
identity, and switching resets Accessibility and Screen Recording for everyone.

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

# The text of the app. swiftpm leaves the compiled catalog in a resource bundle
# of its own; macOS looks for an app's languages in Contents/Resources, and only
# what it finds there is offered to the language picker in System Settings. A
# bundle without them draws its own keys on screen, so this is checked rather
# than assumed.
cp -R App/.build/release/plonk_plonk.bundle/*.lproj "$APP/Contents/Resources/"
if [ ! -f "$APP/Contents/Resources/en.lproj/Localizable.strings" ]; then
	echo "error: the string catalog did not make it into the bundle" >&2
	exit 1
fi
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<!-- plonk://execute-action?name=left-half, for a Raycast script or a
	     Stream Deck button. rectangle:// is declared as well, which makes this
	     app an eligible handler for it and nothing more: whether macOS actually
	     sends those here is a switch on the Shortcuts page, off by default, and
	     RectangleURLs hands the scheme back if it is ever won by accident. -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>dev.plonk.app</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>plonk</string>
			</array>
		</dict>
		<dict>
			<key>CFBundleURLName</key>
			<string>dev.plonk.app.rectangle</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>rectangle</string>
			</array>
		</dict>
	</array>
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

# SECURITY.md tells people to run these two commands on the copy they have, and
# says what the answers will be: no entitlements, hardened runtime. Checking the
# same thing here means the page cannot start lying between one release and the
# next. The commands are the reader's, verbatim.
if [ -n "$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)" ]; then
	echo "error: the signed bundle carries entitlements; SECURITY.md says it has none" >&2
	codesign -d --entitlements - --xml "$APP" >&2
	exit 1
fi
if ! codesign -dv --verbose=2 "$APP" 2>&1 | grep -q 'flags=.*runtime'; then
	echo "error: the signed bundle is not under the hardened runtime; SECURITY.md says it is" >&2
	exit 1
fi

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
