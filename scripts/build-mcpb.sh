#!/bin/sh
# Builds plonk-<version>.mcpb, the bundle format Claude Desktop installs in two
# clicks and Smithery distributes for local servers.
#
# It exists because the alternative is a paragraph of instructions. Without it,
# installing the MCP server means finding the client's JSON config, writing a
# command and an args array into it by hand, and restarting the client — which
# is where most people stop. An .mcpb is a zip carrying the server, its
# dependencies and a manifest, so the client can do all of that itself.
#
# The dependencies are vendored on purpose. `npx -y plonk-mcp` is still the
# documented way in, but it resolves the package at every launch; a bundle that
# already contains what it needs starts offline and cannot be changed under the
# user by a later publish.
#
# Usage: ./scripts/build-mcpb.sh [output-directory] [--smithery]
#
# --smithery writes plonk-<version>-smithery.mcpb instead: the same bundle with
# each tool's inputSchema in the manifest, which the MCPB schema forbids and
# Smithery's registry requires. It is the only build that skips MCPB
# validation, because it is the only one that cannot pass it. See
# make-mcpb-manifest.mjs for the whole story.
set -eu
cd "$(dirname "$0")/.."

OUT=mcp
FLAGS=
SUFFIX=
while [ $# -gt 0 ]; do
	case "$1" in
	--smithery)
		FLAGS=--input-schemas
		SUFFIX=-smithery
		;;
	-*)
		printf 'unknown option: %s\n' "$1" >&2
		exit 2
		;;
	*) OUT=$1 ;;
	esac
	shift
done

STAGE=mcp/.mcpb-build
VERSION=$(node -p 'require("./mcp/package.json").version')

rm -rf "$STAGE"
mkdir -p "$STAGE/server/tools" "$OUT"

# The compiled server, and nothing else from mcp/: no sources, no tests, no
# tsconfig. A bundle is read by clients, not by contributors.
(cd mcp && npm run --silent build)
cp mcp/dist/*.js "$STAGE/server/"
cp mcp/dist/tools/*.js "$STAGE/server/tools/"

# package.json comes along for two reasons: "type": "module", without which
# node reads the server as CommonJS and every import fails, and the lockfile it
# pairs with, which is what makes the vendored tree reproducible.
cp mcp/package.json mcp/package-lock.json "$STAGE/"
(cd "$STAGE" && npm ci --omit=dev --ignore-scripts --silent)

cp docs/logo-400.png "$STAGE/icon.png"
node scripts/make-mcpb-manifest.mjs mcp/dist "$STAGE/manifest.json" $FLAGS

# Validate before packing. The manifest is generated, so a failure here is a
# bug in the generator, and finding it now beats finding it in a client that
# refuses the bundle with no reason given.
BUNDLE=$(cd "$OUT" && pwd)/plonk-$VERSION$SUFFIX.mcpb
rm -f "$BUNDLE"

if [ -z "$SUFFIX" ]; then
	npx --yes @anthropic-ai/mcpb validate "$STAGE/manifest.json"
	npx --yes @anthropic-ai/mcpb pack "$STAGE" "$BUNDLE"
else
	# `mcpb pack` validates too, so the off-spec build cannot go through it.
	# An .mcpb is a zip with manifest.json at the root, which is all the
	# Smithery CLI reads, so zip it directly rather than teach the packer to
	# make an exception. -X keeps the archive free of macOS extended
	# attributes, which nothing downstream reads and every extractor warns on.
	printf 'packing without MCPB validation: this build is deliberately off-spec for Smithery\n' >&2
	(cd "$STAGE" && zip -q -r -X "$BUNDLE" .)
fi

rm -rf "$STAGE"
printf "\nwrote %s\n" "$BUNDLE"
