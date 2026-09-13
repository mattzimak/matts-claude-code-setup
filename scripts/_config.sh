#!/usr/bin/env bash
# _config.sh - shared config reader, sourced by the hooks that need personal data.
#
# The onboarding skill writes one file. Every hook reads from it, so making this
# setup yours means answering questions, never editing a script.
#
# Resolution order:
#   1. $MATTS_SETUP_CONFIG            explicit override (used by the self-test)
#   2. ~/.claude/matts-setup/config.json
#
# It lives outside the plugin cache on purpose: plugin updates replace the plugin
# directory, and your answers must survive that.
#
# Every reader returns empty on a missing file or key. Hooks treat empty as
# "nothing configured" and stay silent - a hook must never fail the session.

MATTS_SETUP_CONFIG="${MATTS_SETUP_CONFIG:-$HOME/.claude/matts-setup/config.json}"

# cfg_get <jq filter>  -> raw value, or empty
cfg_get() {
  [ -r "$MATTS_SETUP_CONFIG" ] || return 0
  jq -r "$1 // empty" "$MATTS_SETUP_CONFIG" 2>/dev/null
}

# cfg_lines <jq filter producing one string per line>  -> lines, or nothing
cfg_lines() {
  [ -r "$MATTS_SETUP_CONFIG" ] || return 0
  jq -r "$1 // empty" "$MATTS_SETUP_CONFIG" 2>/dev/null
}

# cfg_rows <jq filter yielding arrays of strings>
# One line per array, fields joined by the ASCII unit separator (octal 037).
# Read with:  while IFS="$US" read -r a b c; do ...; done < <(cfg_rows '...')
#
# Do NOT use jq's @tsv for this. @tsv escapes backslashes, so a regex such as
# \bAcme\b arrives doubled and silently matches nothing - the hook still runs,
# exits cleanly, and never fires.
US="$(printf '\037')"
cfg_rows() {
  [ -r "$MATTS_SETUP_CONFIG" ] || return 0
  jq -r "$1 | map(. // \"\") | join(\"\\u001f\")" "$MATTS_SETUP_CONFIG" 2>/dev/null
}
