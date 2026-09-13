#!/usr/bin/env bash
# brand-casing-lint.sh - PostToolUse (Edit|Write) hook.
#
# A deterministic backstop for brand and name spelling in written copy.
#
# Why a hook and not just a rule: a full client outreach pack once shipped with
# the brand in the wrong casing, even though the rule already existed in two
# places - the assistant's memory and the client's knowledge base. Instructions
# get missed. A hook fires every time.
#
# Design choices:
#   - It WARNS, it does not block. By PostToolUse time the file is written, so
#     the useful move is to tell the model exactly what to fix, in the same turn.
#     (Compare root-hygiene.sh, which DENIES at PreToolUse because there the
#     damage can still be prevented.)
#   - Silent unless a wrong form is present. No noise on clean writes.
#   - Skips the files that legitimately QUOTE the wrong forms (this hook, the
#     setup log, memory), or it would nag about its own documentation.
#
# To add a brand: append a "bad-regex|canonical" line to BRANDS.
set -euo pipefail

input="$(cat)"
fp="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
body="$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)"
[ -z "$body" ] && exit 0

case "$fp" in
  *"/.claude/hooks/"*|*"/docs/cc-setup/"*|*"/memory/"*) exit 0 ;;
esac

# Only lint writes that actually talk about the brand.
printf '%s' "$body" | grep -qiE 'acme' || exit 0

# bad-form regex | canonical form   (case-sensitive on purpose)
BRANDS='\bAcme [Rr]ockets\b|ACME Rockets
\bACME rockets\b|ACME Rockets
\bAkme\b|ACME'

hits=""
while IFS='|' read -r rx canon; do
  [ -z "$rx" ] && continue
  m="$(printf '%s' "$body" | { grep -oE "$rx" || true; } | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')"
  [ -n "$m" ] && hits+="  - found [$m] -> write \"$canon\""$'\n'
done <<< "$BRANDS"
[ -z "$hits" ] && exit 0

msg="BRAND CASING: the text you just wrote to ${fp:-<unknown>} uses a wrong brand form.
${hits}Fix it now in the same file, then re-check with grep. This is a backstop - the rule applies even when this hook does not fire."

jq -cn --arg m "$msg" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$m}}'
