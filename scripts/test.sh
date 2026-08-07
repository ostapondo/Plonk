#!/bin/sh
# Runs the Swift test suite. The extra flags point at the Testing framework
# bundled with Command Line Tools, which swiftpm does not find on its own
# when Xcode is not installed.
set -eu
cd "$(dirname "$0")/../App"

FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
if [ -d "$FW" ]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$FW" \
        -Xlinker -F -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$FW" \
        -Xlinker -rpath -Xlinker "$LIB" \
        "$@"
fi
exec swift test "$@"
