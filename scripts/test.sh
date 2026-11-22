#!/bin/sh
# Runs the Swift test suite. The extra flags point at the Testing framework
# bundled with Command Line Tools, which swiftpm does not find on its own
# when Xcode is not installed. They are only added when Command Line Tools is
# the active toolchain: with Xcode selected, its compiler would be handed an
# older Testing module than it was built with, and the macros fail to load.
set -eu
cd "$(dirname "$0")/../App"

FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
DEV=${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}
if [ "$DEV" = /Library/Developer/CommandLineTools ] && [ -d "$FW" ]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$FW" \
        -Xlinker -F -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$LIB" \
        "$@"
fi
exec swift test "$@"
