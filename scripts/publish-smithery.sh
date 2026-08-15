#!/bin/sh
# Fills in the Smithery listing for ostapondo/plonk.
#
# `smithery mcp publish` uploads the bundle and nothing else: its only flags
# are --name, --resume and --config-schema, and the bundle path drops the
# manifest's listing fields on the way in (smithery-ai/cli#787). So the card
# shows the qualified name, no description and no icon, however complete
# manifest.json is. The metadata has to be set over the management API
# afterwards, which is what this does.
#
# Everything here comes from a file that already exists, so the card cannot
# say something the package does not. Run it after `smithery mcp publish`,
# with a key from https://smithery.ai/account/api-keys:
#
#   SMITHERY_API_KEY=... ./scripts/publish-smithery.sh
set -eu
cd "$(dirname "$0")/.."

if [ -z "${SMITHERY_API_KEY:-}" ]; then
	printf 'SMITHERY_API_KEY is not set\n' >&2
	exit 1
fi

SERVER=ostapondo/plonk
SITE=https://ostapondo.github.io/Plonk

# node builds the body rather than a heredoc, so the description is escaped as
# JSON by something that knows how, not by hand.
BODY=$(SITE="$SITE" node -e '
	const pkg = require("./mcp/package.json");
	process.stdout.write(JSON.stringify({
		displayName: "Plonk",
		description: pkg.description,
		homepage: process.env.SITE + "/",
		repositoryUrl: "https://github.com/ostapondo/plonk",
		license: pkg.license,
		// A URL, not the multipart upload endpoint: the icon is already
		// served from the project site, and one copy cannot go stale.
		iconUrl: process.env.SITE + "/logo-400.png",
	}));
')

# The qualified name has a slash in it and goes in the path.
ENCODED=$(printf '%s' "$SERVER" | sed 's|/|%2F|')

STATUS=$(curl -sS -X PATCH \
	"https://api.smithery.ai/servers/$ENCODED" \
	-H "Authorization: Bearer $SMITHERY_API_KEY" \
	-H "Content-Type: application/json" \
	-d "$BODY" \
	-o /tmp/smithery-patch.json -w '%{http_code}')

if [ "$STATUS" != "200" ]; then
	printf 'PATCH %s failed with %s:\n' "$SERVER" "$STATUS" >&2
	cat /tmp/smithery-patch.json >&2
	printf '\n' >&2
	rm -f /tmp/smithery-patch.json
	exit 1
fi

rm -f /tmp/smithery-patch.json
printf 'updated https://smithery.ai/server/%s\n' "$SERVER"

# Read it back, because a 200 from the write path is not the same as the card
# having changed.
#
# From the management API, not registry.smithery.ai: the public endpoint sits
# behind a CDN that serves the pre-write copy for a while, so reading it here
# reports a failure that did not happen.
curl -sS "https://api.smithery.ai/servers/$ENCODED" \
	-H "Authorization: Bearer $SMITHERY_API_KEY" | node -e '
	let raw = "";
	process.stdin.on("data", (c) => (raw += c));
	process.stdin.on("end", () => {
		const server = JSON.parse(raw);
		for (const field of ["displayName", "description", "iconUrl"]) {
			console.log(`  ${field}: ${server[field] || "(empty)"}`);
		}
	});
'
