#!/usr/bin/env bash
# cc-setup-log-reminder.sh - PostToolUse (Edit|Write) hook.
# When a session edits Claude Code setup files (.claude/**, CLAUDE.md, .mcp.json),
# inject a reminder to record the change. Fires once per session, using a flag
# file keyed on the session id, so ten edits produce one reminder, not ten.
# Log path from the config: "setup_log": "docs/claude-setup-log.md" (the default).
set -uo pipefail
source "$(dirname "$0")/_config.sh"
LOG_PATH="$(cfg_get '.setup_log')"
[ -z "$LOG_PATH" ] && LOG_PATH="docs/claude-setup-log.md"

input="$(cat)"
fp="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
sid="$(echo "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)"
[ -z "$fp" ] && exit 0

case "$fp" in
  *"/.claude/logs/"*) exit 0 ;;                # telemetry noise, not a setup change
  *"$LOG_PATH"|*"/matts-setup/"*) exit 0 ;;   # the log itself, and this setup's own config
  *"/templates/"*|*"/examples/"*) exit 0 ;;      # a CLAUDE.md shipped as a template is not a setup change
  *"/.claude/"*|*"/CLAUDE.md"|*"/.mcp.json") ;; # setup surface -> remind
  *) exit 0 ;;
esac

flag="/tmp/cc-setup-log-reminder-${sid}"
[ -f "$flag" ] && exit 0
touch "$flag"

msg="SETUP LOG (once before this session ends): you just changed the Claude Code setup (.claude/, CLAUDE.md or .mcp.json). Before finishing, add an entry to $LOG_PATH, newest on top: a dated title, then What changed, Why it is good practice, and Which files - written so a reader with no context could replicate it. One combined entry per session is fine. If the edit was trivial, such as a typo, say so and skip."
jq -cn --arg m "$msg" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$m}}' 
