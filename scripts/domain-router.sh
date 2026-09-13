#!/usr/bin/env bash
# UserPromptSubmit hook - route a session to the right domain rules.
#
# In a workspace with a CLAUDE.md per domain (content/, clients/, dev/...), those
# files load lazily: only when you cd in, or when Claude reads a file under that
# folder. Work from the root and their rules are simply not in context. This
# injects "read that domain's CLAUDE.md first" when a prompt looks like its work.
#
# Your domains come from the config (written by /matts-setup:onboard):
#   "domains": [{"name":"content","claude_md":"content/CLAUDE.md","keywords":"linkedin|caption"}]
# With no domains configured, the domain part stays silent.
#
# Two routes are built in because they are useful for anyone:
#   - media generation, with a NEGATIVE guard first so "docker image" never
#     routes to an image-generation skill
#   - execute-yourself, which stops false "go do it by hand" handoffs
#
# Output contract: additionalContext must be nested inside hookSpecificOutput.
# At the top level it is silently ignored.

source "$(dirname "$0")/_config.sh"

PROMPT="$(jq -r '.prompt // empty')"
[ -z "$PROMPT" ] && exit 0

CONTEXT=""
append() { [ -n "$CONTEXT" ] && CONTEXT+=$'\n\n'; CONTEXT+="$1"; }

# --- Configured domains ---
while IFS="$US" read -r name file kw; do
  [ -z "$name" ] || [ -z "$kw" ] && continue
  if printf '%s' "$PROMPT" | grep -iqE "$kw"; then
    append "DOMAIN ROUTING ($name) - MANDATORY this turn: this looks like $name work, and $file is not loaded automatically from here. READ $file now, before acting, so its rules and skills apply. If this is not $name work, ignore."
  fi
done < <(cfg_rows '.domains[]? | [.name, .claude_md, .keywords]')

# --- Built in: media generation, guarded ---
MEDIA_NEG='docker|container image|base image|og[- ]?image|favicon|image ?tag|image ?src|\.png|\.jpe?g|\.webp|\.svg'
MEDIA_POS='text.?to.?image|text.?to.?video|image prompt|video prompt|photoreal|character sheet'
MEDIA_POS+='|(generat|creat|mak|render|design)[a-z]* (a |an |the |me )*(photo|image|portrait|video|clip|animation)'
if printf '%s' "$PROMPT" | grep -iqE "$MEDIA_POS" && ! printf '%s' "$PROMPT" | grep -iqE "$MEDIA_NEG"; then
  append 'MEDIA ROUTING - MANDATORY this turn: write the prompt deliberately before calling any generation tool. Prompt craft is the expensive part and the part most often skipped. If a prompt-writing skill is installed for this medium, invoke it first, then generate with what it produced. Confirm cost before re-running a failed paid generation.'
fi

# --- Built in: execute yourself ---
EXEC_POS='\bdeploy|\bactivat|credential|api ?key|\btoken\b|\bsecret\b|env ?var|webhook|\bcron\b'
EXEC_POS+='|set ?up|configure|wire up|hook up|integrat|provision'
if printf '%s' "$PROMPT" | grep -iqE "$EXEC_POS"; then
  append 'EXECUTE-YOURSELF - MANDATORY this turn: finish the job in one pass, then force a real run and read the result back from the destination system. A "success" status is not proof the output is correct. Before writing any sentence like "now you need to..." or "go into the UI and...", the step must have been (1) actually attempted, not assumed from memory or docs; (2) attempted more than one way, because a denial on a broad command is not a denial of the goal; and (3) reported with the exact command and what it returned. Genuinely manual: browser OAuth consent, anything needing the user'"'"'s identity or signature, physical actions, and decisions that are theirs to make.'
fi

if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi
exit 0
