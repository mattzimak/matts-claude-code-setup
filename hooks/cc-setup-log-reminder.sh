#!/usr/bin/env bash
# cc-setup-log-reminder.sh - PostToolUse (Edit|Write) hook.
# When a session edits Claude Code setup files (.claude/**, CLAUDE.md, .mcp.json,
# ~/.claude/**), inject a reminder to log the change in docs/cc-setup/LOG.md and
# optionally mirror it to a notes page. Fires once per session.
set -euo pipefail

input="$(cat)"
fp="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
sid="$(echo "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)"
[ -z "$fp" ] && exit 0

case "$fp" in
  *"/.claude/logs/"*) exit 0 ;;                # telemetry noise, not a setup change
  *"/docs/cc-setup/"*) exit 0 ;;               # the log itself
  *"/.claude/"*|*"/CLAUDE.md"|*"/.mcp.json") ;; # setup surface -> remind
  *) exit 0 ;;
esac

flag="/tmp/cc-setup-log-reminder-${sid}"
[ -f "$flag" ] && exit 0
touch "$flag"

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"CC-SETUP LOG (MANDATORY, once before this session ends): you just modified the Claude Code setup (.claude/, CLAUDE.md, or .mcp.json). Before finishing: (1) append an entry to docs/cc-setup/LOG.md (## YYYY-MM-DD - Title, What / Why-best-practice / Files with links, newest on top); (2) optionally mirror it to your notes tool with a small sync script. Description bar: a zero-context reader must be able to replicate the change - event/trigger, exact file paths, registration location, commands; high signal, no fluff. One combined entry per session is fine. If the edit was trivial (typo, comment), note it in the reply and skip."}}
EOF
