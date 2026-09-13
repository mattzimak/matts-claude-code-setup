#!/usr/bin/env bash
# root-hygiene.sh - keep the workspace root free of stray files.
#
# OPT-IN. It does nothing until the config says:
#   "root_hygiene": {"enabled": true, "allow": ["AGENTS.md","CLAUDE.md","README.md"]}
# It is off by default because on an ordinary repository, denying new files in
# the root would get in the way. It earns its place in a multi-domain workspace
# where the root is meant to hold only folders and a few canonical files.
#
# Mode "guard" (PreToolUse, matcher Write): DENY creating a new, non-allowed file
#   directly in the root, with a reason saying where it should go instead.
#   Overwriting an existing root file is allowed - that is an edit, not a stray.
# Mode "sweep" (SessionStart): report stray files that got into the root without
#   the Write tool, dragged in from a file manager or created by a shell command.
# The guard stops new mess; the sweep finds existing mess.

source "$(dirname "$0")/_config.sh"
[ "$(cfg_get '.root_hygiene.enabled')" = "true" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
ALLOW="$(cfg_lines '.root_hygiene.allow[]?')"
[ -z "$ALLOW" ] && ALLOW=$'AGENTS.md\nCHANGELOG.md\nCLAUDE.md\nREADME.md\nWORKLOG.md'

is_allowed() {
  case "$1" in .*) return 0 ;; esac          # dotfiles are config surface
  printf '%s\n' "$ALLOW" | grep -qxF "$1"
}

mode="${1:-guard}"

if [ "$mode" = "guard" ]; then
  input="$(cat)"
  fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  [ -z "$fp" ] && exit 0
  [ "$(dirname "$fp")" != "$ROOT" ] && exit 0
  [ -e "$fp" ] && exit 0
  base="$(basename "$fp")"
  is_allowed "$base" && exit 0
  jq -n --arg b "$base" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("ROOT HYGIENE: the workspace root holds only folders, dotfiles and a few canonical files - do not create " + $b + " there. Retry at the right path: a temporary working file goes to a scratch directory; project material goes into the folder of the project it belongs to.")}}'
  exit 0
fi

if [ "$mode" = "sweep" ]; then
  strays=""
  while IFS= read -r f; do
    b="$(basename "$f")"
    is_allowed "$b" || strays="${strays:+$strays, }$b"
  done < <(find "$ROOT" -maxdepth 1 -type f | sort)
  [ -z "$strays" ] && exit 0
  jq -n --arg s "$strays" '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":("ROOT HYGIENE SWEEP: stray file(s) in the workspace root: " + $s + ". Early in this session, look at each one (read it, do not route by filename alone), move it to the folder it belongs in, and report what moved.")}}'
  exit 0
fi
exit 0
