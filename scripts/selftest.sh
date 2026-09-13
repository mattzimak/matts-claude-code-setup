#!/usr/bin/env bash
# selftest.sh - prove every hook fires when it should and stays silent when it should.
#
# Half the value of a hook is what it correctly ignores, so the silent cases are
# tested as carefully as the firing ones. Runs against a throwaway config and a
# throwaway workspace, so it never reads or changes your real setup.
#
# Usage: selftest.sh            exit 0 if everything passes, 1 otherwise
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/ws" "$TMP/logs"

cat > "$TMP/config.json" <<'JSON'
{
  "domains": [{"name":"content","claude_md":"content/CLAUDE.md","keywords":"\\blinkedin\\b|\\bcaption\\b"}],
  "brands": [{"trigger":"acme","bad":"\\bAcme [Rr]ockets\\b","canonical":"ACME Rockets"}],
  "docs_topics": [{"name":"n8n","pattern":"\\bn8n\\b","library_id":"n8n"}],
  "root_hygiene": {"enabled": true},
  "knowledge_repos": [],
  "notify": "off"
}
JSON
export MATTS_SETUP_CONFIG="$TMP/config.json"
export MATTS_SETUP_LOG_DIR="$TMP/logs"
export CLAUDE_PROJECT_DIR="$TMP/ws"

pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1 - $2"; fail=$((fail+1)); }

# Use printf, never echo: echo can interpret backslash escapes inside a hook's
# message and hand jq broken JSON, which makes a working hook look broken.
expect_emit() {   # name, output
  if printf '%s' "$2" | jq -e '.hookSpecificOutput.hookEventName and (.hookSpecificOutput.additionalContext or .hookSpecificOutput.permissionDecision)' >/dev/null 2>&1
  then ok "$1"; else bad "$1" "expected hook JSON, got: ${2:0:70}"; fi
}
expect_silent() { [ -z "$2" ] && ok "$1" || bad "$1" "expected silence, got: ${2:0:70}"; }

# t <emit|silent> <name> <stdin> <script> [args...]
# Input is passed explicitly. An env-prefixed form like  INPUT=x cmd "$(run ...)"
# does NOT work: the command substitution runs first, in a shell where INPUT is
# unset, so the hook reads nothing and every silent case passes for the wrong reason.
t() {
  local mode="$1" name="$2" input="$3" script="$4"; shift 4
  local out; out="$(printf '%s' "$input" | "$HERE/$script" "$@" 2>/dev/null)"
  if [ "$mode" = emit ]; then expect_emit "$name" "$out"; else expect_silent "$name" "$out"; fi
}

t emit   "evidence audit injects on every prompt"      ''    evidence-audit-directive.sh
t emit   "docs-first: Claude Code is always on"        '{"prompt":"how do claude code hooks work"}' docs-first-reminder.sh
t emit   "docs-first: configured topic fires"          '{"prompt":"fix the n8n webhook node"}'      docs-first-reminder.sh
t silent "docs-first: unrelated prompt is silent"      '{"prompt":"summarise this email"}'           docs-first-reminder.sh
t emit   "router: configured domain fires"             '{"prompt":"draft a linkedin post"}'          domain-router.sh
t emit   "router: media route fires"                   '{"prompt":"generate a photo of a cabin"}'    domain-router.sh
t silent "router: negative guard blocks docker image"  '{"prompt":"rebuild the docker image"}'       domain-router.sh
t silent "router: unrelated prompt is silent"          '{"prompt":"what time is it"}'                domain-router.sh
t emit   "root hygiene: denies a new root file"        "{\"tool_input\":{\"file_path\":\"$TMP/ws/stray.txt\"}}" root-hygiene.sh guard
t silent "root hygiene: allows CLAUDE.md"              "{\"tool_input\":{\"file_path\":\"$TMP/ws/CLAUDE.md\"}}" root-hygiene.sh guard
t silent "root hygiene: allows subfolders"             "{\"tool_input\":{\"file_path\":\"$TMP/ws/docs/x.md\"}}" root-hygiene.sh guard
touch "$TMP/ws/leftover.csv"
t emit   "root hygiene: sweep reports a stray"         ''    root-hygiene.sh sweep
t emit   "brand lint: flags wrong casing"              '{"tool_input":{"file_path":"/x/copy.md","content":"We love Acme rockets"}}' brand-casing-lint.sh
t silent "brand lint: correct casing is silent"        '{"tool_input":{"file_path":"/x/copy.md","content":"We love ACME Rockets"}}' brand-casing-lint.sh
sid="selftest-$$"
t emit   "setup log: first setup edit reminds"         "{\"tool_input\":{\"file_path\":\"/p/.claude/settings.json\"},\"session_id\":\"$sid\"}" cc-setup-log-reminder.sh
t silent "setup log: second edit is deduplicated"      "{\"tool_input\":{\"file_path\":\"/p/.claude/settings.json\"},\"session_id\":\"$sid\"}" cc-setup-log-reminder.sh
rm -f "/tmp/cc-setup-log-reminder-$sid"

printf '%s' '{"tool_input":{"skill":"demo-skill"}}' | "$HERE/skill-usage-logger.sh" >/dev/null 2>&1
[ "$(tail -1 "$TMP/logs/skill-usage.jsonl" 2>/dev/null | jq -r .skill 2>/dev/null)" = "demo-skill" ] \
  && ok "telemetry: logs a skill invocation" || bad "telemetry" "no log line written"

# Opt-in safety: with root hygiene disabled, even a stray root write is allowed.
jq '.root_hygiene.enabled=false' "$TMP/config.json" > "$TMP/off.json"
out="$(printf '%s' "{\"tool_input\":{\"file_path\":\"$TMP/ws/stray2.txt\"}}" | MATTS_SETUP_CONFIG="$TMP/off.json" "$HERE/root-hygiene.sh" guard 2>/dev/null)"
expect_silent "root hygiene: stays off unless enabled" "$out"

# Opt-in safety: with no knowledge repos, auto-commit does nothing at all.
out="$("$HERE/brain-autocommit.sh" </dev/null 2>/dev/null)"
expect_silent "auto-commit: does nothing with no repos configured" "$out"

# Settings merge: adds retention and deny rules, keeps existing ones, idempotent.
echo '{"cleanupPeriodDays":400,"permissions":{"deny":["Read(secrets/**)"]}}' > "$TMP/settings.json"
"$HERE/merge-settings.sh" "$TMP/settings.json" >/dev/null
s="$TMP/settings.json"
[ "$(jq -r .cleanupPeriodDays "$s")" = "400" ] && ok "settings merge: never lowers a higher retention" || bad "settings merge" "retention changed"
jq -e '.permissions.deny | index("Read(secrets/**)")' "$s" >/dev/null && ok "settings merge: keeps existing deny rules" || bad "settings merge" "dropped a rule"
jq -e '.permissions.deny | index("Read(**/.env)")' "$s" >/dev/null && ok "settings merge: adds nested .env block" || bad "settings merge" "missing nested .env"
before="$(jq -S . "$s")"; "$HERE/merge-settings.sh" "$s" >/dev/null
[ "$before" = "$(jq -S . "$s")" ] && ok "settings merge: second run changes nothing" || bad "settings merge" "not idempotent"


# Rules install: appends once, replaces in place, never duplicates, leaves other content alone.
c="$TMP/CLAUDE.md"
printf '# My own notes\n\nKeep this line.\n' > "$c"
"$HERE/install-rules.sh" "$c" >/dev/null
[ "$(grep -c 'matts-setup:rules:start' "$c")" = 1 ] && ok "rules: added once to an existing CLAUDE.md" || bad "rules" "not added exactly once"
grep -q 'Keep this line.' "$c" && ok "rules: leaves the user's own content untouched" || bad "rules" "user content lost"
first="$(cat "$c")"; "$HERE/install-rules.sh" "$c" >/dev/null
[ "$first" = "$(cat "$c")" ] && ok "rules: second run is byte-identical" || bad "rules" "second run changed the file"
sed -i.bak 's/Report only what you can prove/STALE OLD WORDING/' "$c" && rm -f "$c.bak"
"$HERE/install-rules.sh" "$c" >/dev/null
{ ! grep -q 'STALE OLD WORDING' "$c" && [ "$(grep -c 'matts-setup:rules:start' "$c")" = 1 ]; } \
  && ok "rules: replaces an outdated block in place" || bad "rules" "outdated block not replaced cleanly"
"$HERE/install-rules.sh" "$TMP/brand-new/CLAUDE.md" >/dev/null
[ "$(grep -c 'matts-setup:rules:end' "$TMP/brand-new/CLAUDE.md")" = 1 ] && ok "rules: creates a CLAUDE.md that does not exist yet" || bad "rules" "missing file not created"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
