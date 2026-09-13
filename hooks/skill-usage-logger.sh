#!/bin/bash
# PreToolUse hook (matcher: Skill) - passive skill-usage telemetry.
#
# Appends one JSONL line per Skill invocation so we can later see which of the
# 300+ installed skills actually fire and which never trigger (dead weight to
# prune, or good skills with a weak `description` trigger). Non-blocking: it
# only logs, never denies. Summarize with skill-usage-report.sh.
#
# Wired via .claude/settings.local.json (personal telemetry = personal state,
# per the global-vs-project settings model). Log path is gitignored.

# Fail-safe by design: telemetry must NEVER block or error the Skill call it
# observes. Every step is best-effort; the script always exits 0.
{
  LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/logs"
  LOG_FILE="$LOG_DIR/skill-usage.jsonl"
  mkdir -p "$LOG_DIR"

  INPUT="$(cat)"
  SKILL="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // "unknown"' 2>/dev/null)"
  ARGS="$(printf '%s' "$INPUT" | jq -r '.tool_input.args // ""' 2>/dev/null)"
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)"
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  jq -cn --arg ts "$TS" --arg skill "${SKILL:-unknown}" --arg args "$ARGS" --arg cwd "$CWD" \
    '{ts: $ts, skill: $skill, args: $args, cwd: $cwd}' >> "$LOG_FILE" 2>/dev/null
} || true

exit 0
