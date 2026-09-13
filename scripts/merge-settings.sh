#!/usr/bin/env bash
# merge-settings.sh - apply the settings a plugin is not allowed to set itself.
#
# A plugin's own settings.json may only set `agent` and `subagentStatusLine`, so
# two parts of this setup have to be merged into YOUR user settings instead:
#
#   1. cleanupPeriodDays: 365   Claude Code deletes session transcripts after 30
#                               days by default. That once deleted a session that
#                               had built an entire website. Never lowered here:
#                               an existing higher value is kept.
#   2. permissions.deny         harness-enforced block on reading secret files,
#                               including nested .env files in subfolder repos.
#
# Safe by design: backs the file up first, merges rather than replaces, keeps
# every rule you already had, and running it twice changes nothing.
#
# Usage: merge-settings.sh [path-to-settings.json]    (default ~/.claude/settings.json)
#        merge-settings.sh --dry-run [path]           show the result, write nothing
set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
TARGET="${1:-$HOME/.claude/settings.json}"

command -v jq >/dev/null 2>&1 || { echo "merge-settings: jq is required" >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
[ -f "$TARGET" ] || echo '{}' > "$TARGET"
jq -e . "$TARGET" >/dev/null 2>&1 || { echo "merge-settings: $TARGET is not valid JSON, refusing to touch it" >&2; exit 1; }

DENY='["Read(.env)","Read(.env.*)","Read(**/.env)","Read(**/.env.*)","Read(**/*.pem)","Read(**/*.key)","Read(**/*.p12)","Read(**/*.pfx)","Read(**/id_rsa)","Read(**/id_ed25519)"]'

merged="$(jq --argjson deny "$DENY" '
  .cleanupPeriodDays = ([(.cleanupPeriodDays // 0), 365] | max)
  | .permissions = (.permissions // {})
  | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)
' "$TARGET")"

if [ "$DRY" = 1 ]; then
  printf '%s\n' "$merged"
  exit 0
fi

if [ "$(jq -S . "$TARGET")" = "$(printf '%s' "$merged" | jq -S .)" ]; then
  echo "merge-settings: already up to date, nothing changed ($TARGET)"
  exit 0
fi

backup="$TARGET.bak.$(date +%Y%m%d%H%M%S)"
cp "$TARGET" "$backup"
printf '%s\n' "$merged" > "$TARGET"
echo "merge-settings: updated $TARGET"
echo "merge-settings: backup at $backup (restore with: cp \"$backup\" \"$TARGET\")"
