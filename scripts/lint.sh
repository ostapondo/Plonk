#!/bin/sh
# Checks the rules AGENTS.md states but nothing enforced: file length, no
# emoji, no trailing whitespace, a newline at the end of every file.
#
# Deliberately dependency-free. A contributor should not have to install a
# linter to find out whether a pull request will be accepted on style, and the
# app itself ships with no third-party code — a tool the checkout cannot run
# offline would be the only thing in this repo that needs the network.
set -eu
cd "$(dirname "$0")/.."

LIMIT=300
BASELINE=scripts/line-limit-baseline
status=0

say() {
    printf '%s\n' "$1" >&2
    status=1
}

sources() {
    find App/Sources App/Tests mcp/src mcp/test -type f \
        \( -name '*.swift' -o -name '*.ts' -o -name '*.js' \) | sort
}

# --- File length -----------------------------------------------------------
#
# Every file over the limit today is recorded in the baseline with the length
# it had when the rule went in. A file may shrink, never grow, and a new file
# has to come in under the limit outright. That way the rule holds from the
# first commit without a refactor having to land first, and the debt can only
# go one way.
budget_for() {
    awk -v path="$1" '$2 == path { print $1 }' "$BASELINE"
}

for file in $(sources); do
    lines=$(wc -l < "$file" | tr -d ' ')
    budget=$(budget_for "$file")

    if [ -z "$budget" ]; then
        if [ "$lines" -gt "$LIMIT" ]; then
            say "$file: $lines lines, over the $LIMIT-line limit.
  Split it, or put the new logic in a type of its own. AGENTS.md, 'Layout'."
        fi
    elif [ "$lines" -gt "$budget" ]; then
        say "$file: $lines lines, up from $budget in $BASELINE.
  This file is already over the $LIMIT-line limit and may only get shorter.
  Move what you are adding into a type of its own."
    elif [ "$lines" -lt "$budget" ]; then
        printf '%s: down to %s lines from %s. Lower it in %s.\n' \
            "$file" "$lines" "$budget" "$BASELINE" >&2
    fi
done

# --- Emoji -----------------------------------------------------------------
#
# The pattern is built with printf rather than written as an escape, because
# grep has no \x: "[\xF0]" is a character class of backslash, x, F and 0, which
# quietly matches every hex escape in the repo instead. F0 9F is the lead pair
# of the pictograph planes, and that is what this rule means by emoji.
#
# Deliberately not the dingbats at E2 9C. The UI draws ✓ and ✕ as glyphs, the
# same way it draws ⌃⌥⇧, and a rule that cannot tell those from an emoji would
# fail on correct code — the fastest way to teach someone to ignore the linter.
pictograph=$(printf '\360\237')
emoji=$(sources | xargs env LC_ALL=C grep -l "$pictograph" 2>/dev/null || true)
if [ -n "$emoji" ]; then
    say "Emoji in:
$emoji
  No emoji anywhere, user-facing strings included. AGENTS.md, 'Code style'."
fi

# --- Whitespace ------------------------------------------------------------
#
# Indentation is left to .editorconfig rather than checked here: Release.swift
# embeds a shell script whose heredoc is tab-indented on purpose.
trailing=$(sources | xargs grep -l ' $' 2>/dev/null || true)
if [ -n "$trailing" ]; then
    say "Trailing whitespace in:
$trailing"
fi

for file in $(sources); do
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l | tr -d ' ')" -eq 0 ]; then
        say "$file: no newline at end of file."
    fi
done

if [ "$status" -eq 0 ]; then
    printf 'lint: clean\n'
fi
exit "$status"
