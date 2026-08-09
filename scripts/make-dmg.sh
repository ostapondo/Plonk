#!/bin/sh
# Packs an already-signed Plonk.app into the disk image a release ships.
#
# Deliberately hdiutil and nothing else. The usual create-dmg wrapper wants Node
# or Homebrew and drives Finder over AppleScript to place icons, which needs a
# logged-in session a runner does not have.
#
# Run it after notarization has stapled a ticket to the app: what is copied in
# here is what a user drags out, so a bundle stapled afterwards is one nobody
# gets.
set -eu
cd "$(dirname "$0")/.."
. ./version.env

APP=Plonk.app
DMG="Plonk-$MARKETING_VERSION.dmg"
IDENTITY=${PLONK_SIGN_IDENTITY:-Plonk Signing}

if [ ! -d "$APP" ]; then
	echo "error: $APP is not here — run ./scripts/build.sh first" >&2
	exit 1
fi

# An unsigned bundle inside a signed image is still an unsigned bundle, and the
# failure shows up on a user's Mac rather than here.
if ! codesign --verify --deep --strict "$APP" 2>/dev/null; then
	echo "error: $APP is not validly signed; nothing worth packing" >&2
	exit 1
fi

# Both signatures verify on their own, so nothing downstream catches a Developer
# ID app wrapped in a self-signed image — only comparing them does. A run by
# hand does exactly that, since PLONK_SIGN_IDENTITY defaults to development.
SIGNER=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
if [ "$SIGNER" != "$IDENTITY" ]; then
	cat >&2 <<MSG
error: $APP is signed by "$SIGNER", but the image would be signed by "$IDENTITY".

Set PLONK_SIGN_IDENTITY to the identity the app was actually built with.
MSG
	exit 1
fi

STAGING=$(mktemp -d)
MOUNT=
cleanup() {
	if [ -n "$MOUNT" ]; then
		hdiutil detach "$MOUNT" -quiet 2>/dev/null || :
		rmdir "$MOUNT" 2>/dev/null || :
	fi
	rm -rf "$STAGING"
}
trap cleanup EXIT

# ditto rather than cp: a code signature is partly extended attributes, and
# copying without them produces a bundle that fails the check it just passed.
ditto "$APP" "$STAGING/$APP"
ln -s /Applications "$STAGING/Applications"

# -fs stated rather than inherited, so the image does not quietly change format
# the day the runner's macOS does.
rm -f "$DMG"
hdiutil create -volname "Plonk" -srcfolder "$STAGING" \
	-fs HFS+ -format UDZO -imagekey zlib-level=9 -quiet -ov "$DMG"

# Gatekeeper checks the image itself on download, so an unsigned one is a
# warning of its own even when everything inside it is notarized.
#
# --identifier, because codesign otherwise takes one from the filename and stops
# at the first dot: Plonk-0.2.3.dmg signs as "Plonk-0", different on every bump.
codesign --force --identifier dev.plonk.dmg --sign "$IDENTITY" "$DMG"
codesign --verify --strict "$DMG"

# The zip is unpacked and checked before it ships; the image gets the same. That
# it mounts says nothing about whether the bundle inside will still run.
MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -quiet
codesign --verify --deep --strict "$MOUNT/$APP"

# Against the requirement recorded in the repo, not the one this bundle carries:
# comparing a signature with itself proves nothing.
if [ -f scripts/release-requirement ]; then
	codesign --verify -R="$(cat scripts/release-requirement)" "$MOUNT/$APP"
fi

# No digest here: the release path staples this image afterwards, rewriting it.
echo "wrote $DMG"
