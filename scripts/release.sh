#!/bin/sh
# Builds Plonk.app and writes the release zip the Homebrew cask expects,
# notarizing it when a Developer ID certificate is there to do it with.
#
# Whichever path it takes, the archive is checked against the bundle's
# designated requirement before it ships. That check is not a formality: Plonk
# installs an update only when the new build satisfies the requirement the
# running copy carries, and macOS pins Accessibility and Screen Recording to
# the same thing. A release signed with anything else cannot be updated to, and
# takes both permissions away from everyone who installs it by hand. 0.0.3 went
# out ad-hoc signed, zipped by hand, and did exactly that — hence this script
# covering the un-notarized path too, instead of leaving it to `ditto` and hope.
set -eu
cd "$(dirname "$0")/.."
. ./version.env

# Gatekeeper only trusts a Developer ID certificate, and the self-signed
# identity development uses cannot be notarized. Without one the release still
# goes out — it just has to be signed with the same identity as the last one,
# and users meet "Open Anyway" once.
IDENTITY=${PLONK_SIGN_IDENTITY:-}
if [ -z "$IDENTITY" ]; then
	IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null |
		sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
fi
NOTARIZE=yes
case "$IDENTITY" in
"Developer ID Application:"*) ;;
*)
	NOTARIZE=no
	IDENTITY=${PLONK_SIGN_IDENTITY:-Plonk Signing}
	cat >&2 <<MSG
warning: no "Developer ID Application" certificate found, so this release will
not be notarized and first launch will need System Settings > Open Anyway.
Signing with "$IDENTITY" instead — which still has to be the identity every
other release used, or this build cannot be updated to and resets permissions.

Notarization needs a paid Apple Developer account:
  1. developer.apple.com > Certificates > + > Developer ID Application
  2. download it and double-click to add it to the login keychain
MSG
	;;
esac

# notarytool wants credentials it can reuse. Storing them once puts an
# app-specific password in the keychain instead of in this script's environment.
PROFILE=${PLONK_NOTARY_PROFILE:-plonk-notary}
if [ "$NOTARIZE" = yes ] && ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
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

if [ "$NOTARIZE" = yes ]; then
	# notarytool takes a zip, but stapling writes into the bundle, so this
	# upload copy is thrown away and the distributed zip is made again after.
	rm -f "$ZIP"
	ditto -c -k --keepParent "$APP" "$ZIP"
	xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

	# Stapling puts the ticket inside the bundle, so a first launch works
	# offline and without a Gatekeeper round trip.
	xcrun stapler staple "$APP"
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# What a user's Mac will conclude, asked the same way it asks.
codesign --verify --deep --strict --verbose=2 "$APP"
if [ "$NOTARIZE" = yes ]; then
	spctl --assess --type execute --verbose=4 "$APP"
	xcrun stapler validate "$APP"
fi

# The requirement every published release has to satisfy, recorded in the repo
# rather than read back from the bundle being built. Checking a build against
# its own signature proves nothing: it is the same signature. What has to be
# caught is the identity *changing* — a release cut on another Mac, a
# regenerated certificate, a fallback to ad-hoc — because every user's
# permissions and their ability to update at all hang on it staying put.
EXPECTED=scripts/release-requirement
REQUIREMENT=$(codesign -d -r- "$APP" 2>/dev/null | sed -n 's/^designated => //p')
if [ -z "$REQUIREMENT" ]; then
	echo "error: $APP has no designated requirement, so nothing can be updated to it" >&2
	exit 1
fi
if [ ! -f "$EXPECTED" ]; then
	echo "error: $EXPECTED is missing, so there is nothing to hold this release to." >&2
	echo "       Restore it from the repository; do not record this build's own signature." >&2
	exit 1
elif [ "$(cat "$EXPECTED")" != "$REQUIREMENT" ]; then
	cat >&2 <<MSG
error: this build is signed differently from every release so far.

  published: $(cat "$EXPECTED")
  this one:  $REQUIREMENT

Publishing it would revoke Accessibility and Screen Recording for everyone who
installs it, and no copy already out there could update to it. Sign with the
identity the last release used, or — if the change is deliberate, as it will be
the first time a Developer ID is used — update $EXPECTED in the same commit and
say so in the release notes.
MSG
	exit 1
fi

# What ships is the zip, not the bundle it was made from: an archiver that
# mangled the signature would otherwise only show up on a user's Mac.
CHECK=$(mktemp -d)
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$ZIP" "$CHECK"
codesign --verify --deep --strict "$CHECK/$APP"
codesign --verify -R="$REQUIREMENT" "$CHECK/$APP"

echo
[ "$NOTARIZE" = yes ] && echo "notarized $APP and wrote $ZIP" || echo "wrote $ZIP (not notarized)"
echo "requirement: $REQUIREMENT"
echo "sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "update the cask in ostapondo/homebrew-plonk with that version and sha256."
