#!/usr/bin/env bash
# PostToolUse (Edit|Write) hook - brand and name spelling backstop.
#
# Why a hook and not just a rule: a full client outreach pack once shipped with
# the brand in the wrong casing, even though the rule already existed in two
# places - the assistant's memory and the client's knowledge base. Instructions
# get missed. A hook fires every time.
#
# Your brands come from the config (written by /matts-setup:onboard):
#   "brands": [{"trigger":"acme","bad":"\\bAcme [Rr]ockets\\b","canonical":"ACME Rockets"}]
# "trigger" is a cheap case-insensitive pre-filter; "bad" is a case-sensitive regex.
#
# It WARNS rather than denies: by PostToolUse the file is already written, so
# the useful move is saying exactly what to fix in the same turn. It is silent
# on clean writes, and skips files that legitimately quote the wrong forms.

source "$(dirname "$0")/_config.sh"

input="$(cat)"
fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
body="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)"
[ -z "$body" ] && exit 0

case "$fp" in
  *"/.claude/hooks/"*|*"/.claude/plugins/"*|*"/memory/"*|*"/matts-setup/"*) exit 0 ;;
esac

hits=""
while IFS="$US" read -r trigger rx canon; do
  [ -z "$rx" ] && continue
  [ -n "$trigger" ] && ! printf '%s' "$body" | grep -qiE "$trigger" && continue
  m="$(printf '%s' "$body" | { grep -oE "$rx" || true; } | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')"
  [ -n "$m" ] && hits+="  - found [$m] -> write \"$canon\""$'\n'
done < <(cfg_rows '.brands[]? | [.trigger, .bad, .canonical]')

[ -z "$hits" ] && exit 0

msg="BRAND CASING: the text you just wrote to ${fp:-<unknown>} uses a wrong form.
${hits}Fix it now in the same file, then re-check with grep. This is a backstop - the rule applies even when this hook does not fire."

jq -cn --arg m "$msg" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$m}}'
exit 0
