#!/bin/sh
# Checks the claims SECURITY.md makes about this repository, so that a change
# which quietly falsifies one of them fails a pull request instead of leaving
# the document to say something that stopped being true.
#
# The document asks people to grant Accessibility and Screen Recording on the
# strength of what it says the app does and does not do. A claim nobody
# verifies decays: not by anyone lying, but by a later commit adding a host, an
# entitlement or a dependency and nobody remembering the page that promised
# otherwise. These checks are the memory.
#
# Only the claims a checkout can settle are here. The ones about a signed
# bundle belong where the signing happens, in scripts/build.sh, and the ones
# about the running server are unit tests. Dependency-free for the same reason
# lint.sh is.
set -eu
cd "$(dirname "$0")/.."

status=0

say() {
	printf '%s\n' "$1" >&2
	status=1
}

# --- Entitlements ----------------------------------------------------------
#
# "The bundle ships with no entitlements at all, under the hardened runtime."
#
# Empty entitlements are the absence of a thing, which is exactly the kind of
# claim that breaks silently: adding one is a single flag, and nothing about
# the build gets louder when it appears.

entitlements=$(find . -name '*.entitlements' -not -path './.git/*')
if [ -n "$entitlements" ]; then
	say "SECURITY.md says the bundle ships with no entitlements, but an .entitlements file exists:"
	printf '%s\n' "$entitlements" >&2
fi

# Only on a line that signs. `codesign -d --entitlements -` reads them back and
# is how build.sh proves there are none, so matching the flag alone would flag
# the check that enforces this very claim.
if grep -E -- '--sign' scripts/build.sh scripts/release.sh | grep -q -- '--entitlements'; then
	say "a signing script passes --entitlements; SECURITY.md says the bundle has none"
fi

if ! grep -q -- '--options runtime' scripts/build.sh; then
	say "scripts/build.sh no longer signs with --options runtime; SECURITY.md claims the hardened runtime"
fi

# --- Dependencies ----------------------------------------------------------
#
# "no third-party Swift dependencies at all, and two on the npm side, the
# official MCP SDK and zod."
#
# This is the claim most likely to go stale, because adding a dependency is
# routine and feels like nothing. It is also the one that most changes what a
# reader has to audit: the line about ~7,600 lines of Swift being readable
# holds only while that is all the code there is.

if grep -q '\.package(' App/Package.swift; then
	say "App/Package.swift declares an external dependency; SECURITY.md claims none"
fi

EXPECTED_NPM='@modelcontextprotocol/sdk zod'
# Every key in the block, not one per line: a dependency added beside another
# on the same line is still a dependency, and a line-oriented read would walk
# straight past it.
ACTUAL_NPM=$(
	sed -n '/^[[:space:]]*"dependencies"/,/}/p' mcp/package.json |
		sed '1d' |
		grep -oE '"[^"]+"[[:space:]]*:' |
		sed 's/"//g; s/[[:space:]]*:$//' | sort | tr '\n' ' '
)
ACTUAL_NPM=${ACTUAL_NPM% }
if [ "$ACTUAL_NPM" != "$EXPECTED_NPM" ]; then
	say "mcp/package.json runtime dependencies are '$ACTUAL_NPM'; SECURITY.md names '$EXPECTED_NPM'"
fi

# --- Network ---------------------------------------------------------------
#
# "One host - api.github.com, for the update check - and one loopback listener
# on 127.0.0.1:43917."
#
# github.com is allowed here because it is a link the app opens in your
# browser, not a connection the app makes. The point of the list is that a host
# nobody decided to add cannot arrive unnoticed; anything new fails and someone
# has to either justify it or update the page.

for host in $(find App/Sources -type f -name '*.swift' | sort | xargs grep -hoE 'https?://[a-zA-Z0-9._-]+' | sed 's|https\{0,1\}://||' | sort -u); do
	case "$host" in
	api.github.com | github.com) ;;
	*) say "Swift sources reach $host; SECURITY.md names api.github.com as the only host" ;;
	esac
done

# The MCP server builds most of its URLs from a variable, so listing hosts
# there says little. What can be checked is that no literal names a real
# machine: every address in that source either starts with 127.0.0.1 or is a
# template hole. A hostname made of letters is the thing that must not appear.

named_hosts=$(find mcp/src -type f -name '*.ts' | xargs grep -nE 'https?://[a-zA-Z]' || true)
if [ -n "$named_hosts" ]; then
	say "mcp/src contains a URL naming a host by name; the MCP server should only speak to loopback:"
	printf '%s\n' "$named_hosts" >&2
fi

if ! grep -q 'static let port: UInt16 = 43917' App/Sources/plonk/ControlServer.swift; then
	say "the control server no longer binds 43917; SECURITY.md documents that port"
fi

# --- The token -------------------------------------------------------------
#
# "written on first launch to ~/Library/Application Support/Plonk/token with
# mode 600", and it fails closed when the file cannot be held as a secret.
#
# O_EXCL and O_NOFOLLOW are the part that is easy to lose in a refactor and
# impossible to see afterwards: without them the same code still writes a
# token, still reports mode 600, and will happily follow a symlink someone else
# put there first.

if ! grep -q 'O_CREAT | O_EXCL | O_NOFOLLOW, 0o600' App/Sources/plonk/APIToken.swift; then
	say "the token is no longer created with O_EXCL, O_NOFOLLOW and mode 600; SECURITY.md describes all three"
fi

# --- Result ----------------------------------------------------------------

if [ "$status" -eq 0 ]; then
	echo "security claims hold"
fi

exit "$status"
