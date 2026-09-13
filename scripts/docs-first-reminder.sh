#!/usr/bin/env bash
# UserPromptSubmit hook - documentation-first enforcement.
#
# Models answer fast-moving tools from training memory, and that memory is stale.
# When a prompt names a tool you want grounded in CURRENT official docs, this
# injects a reminder to read those docs before answering, building or debugging.
#
# Claude Code itself is always on, because its configuration changes faster than
# any model's training data. Add your own tools in the config:
#   "docs_topics": [{"name":"n8n","pattern":"n8n","library_id":"n8n"}]
# The reminder points at the Context7 MCP server; if you use a different docs
# source, the instruction still holds - read current docs, not memory.

source "$(dirname "$0")/_config.sh"

PROMPT="$(jq -r '.prompt // empty')"
[ -z "$PROMPT" ] && exit 0

CONTEXT=""
append() { [ -n "$CONTEXT" ] && CONTEXT+=$'\n\n'; CONTEXT+="$1"; }

remind() { # name, library id
  append "DOCUMENTATION-FIRST ($1) - MANDATORY this turn: before answering or changing anything involving $1, consult CURRENT official documentation (via the Context7 MCP server: resolve-library-id, then query-docs, library \"$2\") as the primary source. Do not answer from memory. Cite what the docs return."
}

printf '%s' "$PROMPT" | grep -iqE 'claude[ -]?code' && remind "Claude Code" "/websites/code_claude"

while IFS="$US" read -r name pattern lib; do
  [ -z "$name" ] || [ -z "$pattern" ] && continue
  printf '%s' "$PROMPT" | grep -iqE "$pattern" && remind "$name" "${lib:-$name}"
done < <(cfg_rows '.docs_topics[]? | [.name, .pattern, .library_id]')

if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi
exit 0
