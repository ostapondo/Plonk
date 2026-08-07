#!/bin/sh
# Builds, notarizes and staples Plonk.app, then writes the release zip the
# Homebrew cask expects. Everything here needs a paid Apple Developer account;
# scripts/build.sh alone is enough for development.
set -eu
cd "$(dirname "$0")/.."
. ./version.env

# Gatekeeper only trusts a Developer ID certificate. The self-signed identity
# development uses cannot be notarized, so refuse early rather than fail three
# minutes in, after the upload.
IDENTITY=${PLONK_SIGN_IDENTITY:-}
if [ -z "$IDENTITY" ]; then
	IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null |
		sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
fi
case "$IDENTITY" in
"Developer ID Application:"*) ;;
*)
	cat >&2 <<MSG
error: no "Developer ID Application" certificate found.

Notarization needs one, which needs a paid Apple Developer account:
  1. developer.apple.com > Certificates > + > Developer ID Application
  2. download it and double-click to add it to the login keychain

Then set PLONK_SIGN_IDENTITY to its full name, or let this script find it.
MSG
	exit 1
	;;
esac

# notarytool wants credentials it can reuse. Storing them once puts an
# app-specific password in the keychain instead of in this script's environment.
PROFILE=${PLONK_NOTARY_PROFILE:-plonk-notary}
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
	cat >&2 <<MSG
error: no stored notarization credentials under profile "$PROFILE".

Create an app-specific password at appleid.apple.com, then run once:
  xcrun notarytool store-credentials "$PROFILE" \\
    --apple-id you@example.com --team-id TEAMID --password APP-SPECIFIC-PASSWORD
MSG
	exit 1
fi

PLONK_SIGN_IDENTITY="$IDENTITY" ./scripts/build.sh

APP=Plonk.app
ZIP="Plonk-$MARKETING_VERSION.zip"

# notarytool takes a zip, but stapling writes into the bundle, so this upload
# copy is thrown away and the distributed zip is made again afterwards.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

# Stapling puts the ticket inside the bundle, so a first launch works offline
# and without a Gatekeeper round trip.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# What a user's Mac will conclude, asked the same way it asks.
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
xcrun stapler validate "$APP"

echo
echo "notarized $APP and wrote $ZIP"
echo "sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "update the cask in ostapondo/homebrew-plonk with that version and sha256."
