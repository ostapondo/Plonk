#!/bin/sh
# Creates the self-signed code-signing identity Plonk is signed with, as a .p12
# file.
#
# Certificate Assistant can make one too, but only into the login keychain, and
# macOS will not let a key born there back out again: `security export` answers
# "the contents of this item cannot be retrieved" and the only way past it is
# the Keychain Access window. That is fine once and miserable forever — the
# release workflow needs the key as a file it can put in a secret. So the key
# is generated as a file first and imported afterwards, which is the same
# certificate either way and one less thing that can only be done by hand.
#
# Run it once. Keep the .p12 somewhere safe: every installed copy of Plonk will
# only accept an update signed with this key, and there is no way to reissue it.
set -eu
cd "$(dirname "$0")/.."

NAME=${PLONK_SIGN_IDENTITY:-Plonk Signing}
OUT=${1:-./plonk-signing.p12}
OPENSSL=${OPENSSL:-/opt/homebrew/opt/openssl@3/bin/openssl}
[ -x "$OPENSSL" ] || OPENSSL=openssl

if [ -e "$OUT" ]; then
	echo "error: $OUT already exists — refusing to overwrite an identity" >&2
	exit 1
fi

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

# codeSigning EKU is what makes macOS treat this as an identity it can sign
# with; CA:true is what lets it be trusted as its own root, since nothing else
# vouches for it. Ten years, because a signing identity that expires takes
# every installed copy's ability to update with it.
"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
	-keyout "$D/key.pem" -out "$D/cert.pem" \
	-subj "/CN=$NAME/O=Plonk" \
	-addext "basicConstraints=critical,CA:true" \
	-addext "keyUsage=critical,digitalSignature,keyCertSign" \
	-addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# -legacy, or OpenSSL 3 packs the archive with AES-256 and PBKDF2 and macOS
# answers "MAC verification failed" no matter how right the password is.
PASSWORD=$("$OPENSSL" rand -hex 24)
"$OPENSSL" pkcs12 -export -legacy \
	-inkey "$D/key.pem" -in "$D/cert.pem" -name "$NAME" \
	-passout "pass:$PASSWORD" -out "$OUT"

FINGERPRINT=$("$OPENSSL" x509 -in "$D/cert.pem" -noout -fingerprint -sha1 |
	sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z')

cat <<MSG
wrote $OUT

  identity:    $NAME
  sha1:        $FINGERPRINT
  requirement: identifier "dev.plonk.app" and certificate leaf = H"$FINGERPRINT"

password (needed to import it, and by PLONK_SIGN_CERT_PASSWORD):

  $PASSWORD

To sign locally, import it and tell macOS to trust it as a root — without the
trust setting it is not a *valid* identity and scripts/build.sh will not see it:

  security import "$OUT" -k ~/Library/Keychains/login.keychain-db -P '$PASSWORD' -T /usr/bin/codesign
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <(openssl pkcs12 -in "$OUT" -clcerts -nokeys -legacy -passin pass:'$PASSWORD')

To let the release workflow sign with it:

  base64 -i "$OUT" | gh secret set PLONK_SIGN_CERT_P12 --repo ostapondo/Plonk
  gh secret set PLONK_SIGN_CERT_PASSWORD --repo ostapondo/Plonk
MSG
