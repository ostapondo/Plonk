#!/bin/sh
# Packs an already-signed Plonk.app into the disk image a release ships.
#
# The zip stays the primary artifact — the Homebrew cask pins its sha256 and
# every published release so far carries one. This is for the other half of
# people, who arrive from the site rather than from brew, and for whom a zip
# that expands into a bundle wherever the browser happened to put it is a worse
# first minute than a window with an arrow pointing at Applications.
#
# Deliberately hdiutil and nothing else. The usual create-dmg wrapper wants
# Node or Homebrew and drives Finder over AppleScript to place icons, which
# needs a logged-in session that a runner does not have. A plain image with the
# app and a symlink beside it is what those scripts produce anyway, minus the
# background picture.
#
# Run it after the app is signed, and after notarization has stapled a ticket
# to it: what is copied in here is what a user drags out, so a bundle stapled
# afterwards is a bundle nobody gets.
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

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

# ditto rather than cp: a code signature is partly extended attributes, and
# copying without them produces a bundle that fails the check it just passed.
ditto "$APP" "$STAGING/$APP"
ln -s /Applications "$STAGING/Applications"

# HFS+ rather than the APFS default. An APFS image will not mount on anything
# older than the Mac that made it in the way this one needs, and the app runs
# on macOS 13 — the image should not be the part that refuses.
rm -f "$DMG"
hdiutil create -volname "Plonk" -srcfolder "$STAGING" \
	-fs HFS+ -format UDZO -imagekey zlib-level=9 -quiet -ov "$DMG"

# Signing the image is separate from signing the app inside it. Gatekeeper
# checks the image on download, and an unsigned one is a warning of its own
# even when everything it carries is notarized.
#
# --identifier, because left to itself codesign takes one from the filename and
# stops at the first dot: Plonk-0.2.3.dmg signs as "Plonk-0", which is both
# wrong and different every time the minor version moves.
codesign --force --identifier dev.plonk.dmg --sign "$IDENTITY" "$DMG"
codesign --verify --strict "$DMG"

echo "wrote $DMG"
echo "sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
