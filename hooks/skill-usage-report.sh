#!/bin/bash
# Summarize skill-usage telemetry captured by skill-usage-logger.sh.
# Usage: .claude/hooks/skill-usage-report.sh
#
# Prints skills ranked by invocation count (most-used first). Cross-reference
# against the installed skill list to spot skills that NEVER appear here -
# candidates to prune or to give a stronger `description` trigger.

set -euo pipefail

LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/logs/skill-usage.jsonl"

if [ ! -s "$LOG_FILE" ]; then
  echo "No skill-usage data yet at $LOG_FILE"
  echo "(The logger fires on the next Skill invocation.)"
  exit 0
fi

TOTAL="$(wc -l < "$LOG_FILE" | tr -d ' ')"
UNIQUE="$(jq -r '.skill' "$LOG_FILE" | sort -u | wc -l | tr -d ' ')"
SINCE="$(head -1 "$LOG_FILE" | jq -r '.ts')"

echo "Skill usage  -  $TOTAL invocations across $UNIQUE distinct skills since $SINCE"
echo "------------------------------------------------------------"
jq -r '.skill' "$LOG_FILE" | sort | uniq -c | sort -rn | \
  awk '{printf "  %5d  %s\n", $1, $2}'
