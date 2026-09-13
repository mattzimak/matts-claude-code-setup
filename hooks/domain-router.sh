#!/bin/bash
# UserPromptSubmit hook - route a root-folder session to the right domain brain.
#
# Problem: in a multi-domain workspace, each domain keeps its own CLAUDE.md
# (content/, clients/, dev/...). Those files load lazily - only when you cd into
# the domain or Claude reads a file under it. If you work from the workspace root
# most of the time, their rules and skill stacks are simply not in context.
#
# Fix: when a prompt looks like domain work, inject a mandatory reminder to READ
# that domain's CLAUDE.md before acting. It is deterministic, so it survives long
# sessions where the routing paragraph in the root CLAUDE.md drifts out of view.
#
# Design rules this file follows:
#   - Emit nothing on no match. Silence is the default; noise trains you to skip it.
#   - Each domain is an independent `if` block, so one prompt can hit several.
#   - Put NEGATIVE guards before broad positive patterns. "image" in a media
#     prompt and "image" in "docker image" are different jobs.
#   - Some routes guarantee a SKILL fires rather than a file gets read. Skill
#     activation is model judgment; a hook is not.
#
# Output contract: additionalContext must be nested inside hookSpecificOutput.
# At the top level it is silently ignored.

PROMPT="$(jq -r '.prompt // empty')"

CONTEXT=""
append() { [ -n "$CONTEXT" ] && CONTEXT+=$'\n\n'; CONTEXT+="$1"; }

# --- Example domain 1: content (posts, captions, newsletters) ---
if printf '%s' "$PROMPT" | grep -iqE 'linkedin|instagram|tiktok|\btweet\b|caption|carousel|newsletter|blog post'; then
  append 'DOMAIN ROUTING (content) - MANDATORY this turn: this looks like content work and you are likely in the workspace root, where content/CLAUDE.md is NOT auto-loaded. READ content/CLAUDE.md now, before acting, so its voice rules and skills apply. If this is not content work, ignore.'
fi

# --- Example domain 2: media generation, with a negative guard ---
# The negative list stops dev and infra senses of "image" from matching.
MEDIA_NEG='docker|container image|base image|og[- ]?image|favicon|image ?tag|image ?src|\.png|\.jpe?g|\.webp|\.svg'
MEDIA_POS='text.?to.?image|text.?to.?video|image prompt|video prompt|photoreal|character sheet'
MEDIA_POS+='|(generat|creat|mak|render|design)[a-z]* (a |an |the |me )*(photo|image|portrait|video|clip|animation)'
if printf '%s' "$PROMPT" | grep -iqE "$MEDIA_POS" && ! printf '%s' "$PROMPT" | grep -iqE "$MEDIA_NEG"; then
  append 'MEDIA ROUTING - MANDATORY this turn: invoke the prompt-writing skill for the medium BEFORE calling any generation tool. Prompt craft is the expensive part and the part most often skipped. Only then execute the generation with the prompt that skill produced. Confirm cost before re-running a failed paid generation.'
fi

# --- Cross-cutting: stop false manual handoffs ---
# The most common failure in agent work is not missing capability. It is the
# agent ASSUMING a limit instead of testing it, or reading one blocked command as
# proof the whole goal is blocked, then telling you to "go do X in the UI".
EXEC_POS='\bdeploy|\bactivat|credential|api ?key|\btoken\b|\bsecret\b|env ?var|webhook|\bcron\b'
EXEC_POS+='|set ?up|configure|wire up|hook up|integrat|provision'
if printf '%s' "$PROMPT" | grep -iqE "$EXEC_POS"; then
  append 'EXECUTE-YOURSELF - MANDATORY this turn: finish the job in one pass, then force a real run and read the result back from the destination system. A "success" status is not proof the output is correct. Before writing any sentence like "now you need to..." or "go into the UI and...", the step must have been (1) actually attempted, not assumed from memory or docs; (2) attempted more than one way, because a denial on a broad command is not a denial of the goal - narrow it and retry, or find the adjacent endpoint; and (3) reported with the exact command and what it returned. Genuinely manual: browser OAuth consent, anything needing your identity or signature, physical actions, and decisions that are yours to make.'
fi

if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi

exit 0
