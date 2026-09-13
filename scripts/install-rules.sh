#!/usr/bin/env bash
# install-rules.sh - put the operating rules into a CLAUDE.md, exactly once.
#
# A plugin's own CLAUDE.md is never loaded into context, so the operating rules
# only take effect once they sit in YOUR CLAUDE.md. The rules live between two
# marker comments. If the markers are already there, the block between them is
# replaced; otherwise the block is appended. Nothing outside the markers is ever
# touched, and running this twice leaves the file byte-identical.
#
# This is a script rather than an instruction to the model on purpose: "append
# once, never duplicate" is a mechanical rule, and mechanical rules drift when
# left to judgment.
#
# Usage: install-rules.sh [path-to-CLAUDE.md]     (default ~/.claude/CLAUDE.md)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$HERE/../templates/CLAUDE.md"
TARGET="${1:-$HOME/.claude/CLAUDE.md}"
START='<!-- matts-setup:rules:start'
END='<!-- matts-setup:rules:end -->'

[ -r "$TEMPLATE" ] || { echo "install-rules: template not found at $TEMPLATE" >&2; exit 1; }
mkdir -p "$(dirname "$TARGET")"
[ -f "$TARGET" ] || : > "$TARGET"

if grep -qF "$START" "$TARGET" && grep -qF "$END" "$TARGET"; then
  # Replace everything from the start marker line through the end marker line.
  awk -v start="$START" -v end="$END" -v tpl="$TEMPLATE" '
    index($0, start) == 1 { while ((getline line < tpl) > 0) print line; skip = 1; next }
    skip && index($0, end) == 1 { skip = 0; next }
    !skip { print }
  ' "$TARGET" > "$TARGET.tmp"
  mv "$TARGET.tmp" "$TARGET"
  echo "install-rules: updated the existing rules block in $TARGET"
else
  { [ -s "$TARGET" ] && printf '\n'; cat "$TEMPLATE"; } >> "$TARGET"
  echo "install-rules: added the rules block to $TARGET"
fi
