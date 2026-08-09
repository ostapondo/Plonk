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

# notarytool wants credentials, and the two ways of giving them suit different
# places. On a laptop a keychain profile is the kind one: stored once, and an
# app-specific password never appears in this script's environment. A runner has
# no keychain worth persisting to and no way to answer store-credentials, so CI
# passes an App Store Connect API key instead — three values that can be handed
# over as secrets and revoked one key at a time, without touching the Apple ID
# the account signs in with.
#
# A function rather than a variable holding the flags: this is POSIX sh with no
# arrays, and an issuer UUID interpolated into an unquoted expansion is how
# argument lists start splitting on surprises.
PROFILE=${PLONK_NOTARY_PROFILE:-plonk-notary}
notary() {
	if [ -n "${PLONK_NOTARY_KEY:-}" ]; then
		xcrun notarytool "$@" \
			--key "$PLONK_NOTARY_KEY" \
			--key-id "$PLONK_NOTARY_KEY_ID" \
			--issuer "$PLONK_NOTARY_ISSUER"
	else
		xcrun notarytool "$@" --keychain-profile "$PROFILE"
	fi
}

# Half a key is worse than none: it fails after the build, on the upload, with
# whatever message Apple gives an incomplete request.
if [ "$NOTARIZE" = yes ] && [ -n "${PLONK_NOTARY_KEY:-}" ]; then
	if [ ! -f "$PLONK_NOTARY_KEY" ]; then
		echo "error: PLONK_NOTARY_KEY is set to \"$PLONK_NOTARY_KEY\", which is not a file" >&2
		exit 1
	fi
	if [ -z "${PLONK_NOTARY_KEY_ID:-}" ] || [ -z "${PLONK_NOTARY_ISSUER:-}" ]; then
		echo "error: PLONK_NOTARY_KEY needs PLONK_NOTARY_KEY_ID and PLONK_NOTARY_ISSUER with it" >&2
		exit 1
	fi
fi

if [ "$NOTARIZE" = yes ] && ! notary history >/dev/null 2>&1; then
	cat >&2 <<MSG
error: notarization credentials were rejected, or there are none.

On a laptop, create an app-specific password at appleid.apple.com and run once:
  xcrun notarytool store-credentials "$PROFILE" \\
    --apple-id you@example.com --team-id TEAMID --password APP-SPECIFIC-PASSWORD

In CI, set PLONK_NOTARY_KEY to the .p8 App Store Connect key, with
PLONK_NOTARY_KEY_ID and PLONK_NOTARY_ISSUER beside it.
MSG
	exit 1
fi

PLONK_SIGN_IDENTITY="$IDENTITY" ./scripts/build.sh

APP=Plonk.app
ZIP="Plonk-$MARKETING_VERSION.zip"

# The requirement every published release has to satisfy, recorded in the repo
# rather than read back from the bundle being built. Checking a build against
# its own signature proves nothing: it is the same signature. What has to be
# caught is the identity *changing* — a release cut on another Mac, a
# regenerated certificate, a fallback to ad-hoc — because every user's
# permissions and their ability to update at all hang on it staying put.
#
# Checked here, before notarization, because Apple is the slow and finite half
# of this script. A build that is going to be rejected for its signature should
# not spend a submission and ten minutes finding that out — and the first
# Developer ID release is exactly the case that trips it, deliberately.
EXPECTED=scripts/release-requirement
REQUIREMENT=$(codesign -d -r- "$APP" 2>/dev/null | sed -n 's/^designated => //p')
if [ -z "$REQUIREMENT" ]; then
	echo "error: $APP has no designated requirement, so nothing can be updated to it" >&2
	exit 1
fi
if [ ! -f "$EXPECTED" ]; then
	printf '%s\n' "$REQUIREMENT" > "$EXPECTED"
	echo "note: recorded this release's requirement in $EXPECTED — commit it." >&2
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

if [ "$NOTARIZE" = yes ]; then
	# notarytool takes a zip, but stapling writes into the bundle, so this
	# upload copy is thrown away and the distributed zip is made again after.
	rm -f "$ZIP"
	ditto -c -k --keepParent "$APP" "$ZIP"
	notary submit "$ZIP" --wait

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

# What ships is the zip, not the bundle it was made from: an archiver that
# mangled the signature would otherwise only show up on a user's Mac.
CHECK=$(mktemp -d)
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$ZIP" "$CHECK"
codesign --verify --deep --strict "$CHECK/$APP"
codesign --verify -R="$REQUIREMENT" "$CHECK/$APP"

# The disk image exists only on the notarized path. Un-notarized it would be a
# second artifact meeting the same "Open Anyway" wall as the zip, and one more
# thing for the README to explain in exchange for nothing. Built here, after
# the requirement check, so a release about to be rejected does not get packed
# twice — and after stapling, so the bundle a user drags to Applications
# carries its own ticket and does not need the network on first launch.
DMG="Plonk-$MARKETING_VERSION.dmg"
if [ "$NOTARIZE" = yes ]; then
	PLONK_SIGN_IDENTITY="$IDENTITY" ./scripts/make-dmg.sh

	# The image is notarized in its own right. Stapling the app inside it is
	# not enough: what a browser marks with the quarantine bit is the .dmg,
	# and that is the file Gatekeeper is asked about first.
	notary submit "$DMG" --wait
	xcrun stapler staple "$DMG"

	# How macOS reads a downloaded image, rather than how it reads an app it
	# has been asked to run. Both have to pass, and a stapled pair passes
	# offline.
	spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
	xcrun stapler validate "$DMG"
fi

echo
[ "$NOTARIZE" = yes ] && echo "notarized $APP and wrote $ZIP" || echo "wrote $ZIP (not notarized)"
echo "requirement: $REQUIREMENT"
echo "sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
if [ "$NOTARIZE" = yes ]; then
	echo "dmg sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
fi
echo "update the cask in ostapondo/homebrew-plonk with that version and sha256."
