#!/usr/bin/env bash
# root-hygiene.sh - keeps the workspace root free of stray files.
# Root contract: the workspace root holds ONLY folders + the 5 canonical md files
# (AGENTS, CHANGELOG, CLAUDE, README, WORKLOG) + dotfiles (config surface).
#
# Mode "guard" (PreToolUse, matcher Write): DENY creating a new non-whitelisted
#   file directly in root; the reason tells the agent where to write instead.
#   Overwriting an existing root file is allowed (that is an edit, not a stray).
# Mode "sweep" (SessionStart): if stray files are already sitting in root
#   (dropped via bash, Finder, screenshots...), inject a reminder to route them.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
is_allowed() {
  case "$1" in
    .*) return 0 ;;  # dotfiles: .gitignore, .mcp.json, .env, ...
    AGENTS.md|CHANGELOG.md|CLAUDE.md|README.md|WORKLOG.md) return 0 ;;
  esac
  return 1
}

mode="${1:-guard}"

if [ "$mode" = "guard" ]; then
  input="$(cat)"
  fp="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  [ -z "$fp" ] && exit 0
  [ "$(dirname "$fp")" != "$ROOT" ] && exit 0   # only files directly in root
  [ -e "$fp" ] && exit 0                        # existing root file -> edit, fine
  base="$(basename "$fp")"
  is_allowed "$base" && exit 0
  jq -n --arg b "$base" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("ROOT HYGIENE: the workspace root holds only folders + AGENTS/CHANGELOG/CLAUDE/README/WORKLOG.md + dotfiles - do not create " + $b + " there. Route it and retry at the correct path: temp/working file -> the session scratchpad dir; staging for a human -> assets/; project material (screenshots, exports, data) -> the owning project folder (<project>/assets/, plans/, docs/). Rule: Root hygiene in CLAUDE.md.")}}'
  exit 0
fi

if [ "$mode" = "sweep" ]; then
  strays=""
  while IFS= read -r f; do
    b="$(basename "$f")"
    is_allowed "$b" || strays="${strays:+$strays, }$b"
  done < <(find "$ROOT" -maxdepth 1 -type f | sort)
  [ -z "$strays" ] && exit 0
  jq -n --arg s "$strays" '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":("ROOT HYGIENE SWEEP: stray file(s) in the workspace root: " + $s + ". Root holds only folders + the 5 canonical md files + dotfiles. Early this session, route each stray to its real home (assets/ staging, or the owning project folder - LOOK at each file first, e.g. Read images, do not route by filename alone) and report what moved. Rule: Root hygiene in CLAUDE.md.")}}'
  exit 0
fi
