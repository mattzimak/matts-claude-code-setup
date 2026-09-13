#!/usr/bin/env bash
# brain-autocommit.sh - keep the company/client brain repos committed + pushed automatically.
#
# WHY: the "brain" repos (one per company or client, plus a knowledge base) live OUTSIDE
# this workspace. Work done in a session lands on disk there but used to sit uncommitted until
# someone remembered. The rule: whenever a brain gets fed new information, it must
# be committed AND pushed in the same session so the remote is always the source of truth.
#
# WIRED AS: a `Stop` hook in .claude/settings.json - runs when Claude finishes responding.
#
# SAFETY (this thing writes to git remotes unattended, so it is deliberately conservative):
#   - Secrets: runs `gitleaks protect --staged` before every commit. Any finding => that repo is
#     SKIPPED entirely (nothing committed, nothing pushed) and reported. Never allowlists blind.
#   - Never force-pushes. Never rewrites history. Never touches a repo mid-rebase/merge/cherry-pick.
#   - Detached HEAD => skip (no branch to push).
#   - No upstream => commits locally, then tries `push -u origin <branch>`; failure is reported.
#   - Remote moved on => `pull --rebase`; if that conflicts, it aborts the rebase and leaves the
#     commit local, so a human resolves it. Nothing is discarded.
#   - Honours a per-repo opt-out: a `.no-autocommit` file at the repo root.
#
# Exit code is always 0 - a hook that fails must never block the session.

set -uo pipefail

BRAINS=(
  "$HOME/code/company-brain"
  "$HOME/code/client-a-brain"
  "$HOME/code/knowledge"
)

# MUST be an absolute path outside the brains. Using $PWD here caused the hook to write its own
# log INTO the brain repo it was syncing, and then commit it (caught in testing 2026-07-29).
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/brain-autocommit.log"
stamp() { date '+%Y-%m-%d %H:%M:%S'; }
say()   { printf '%s\n' "$*" >> "$LOG"; }

report=""
add_report() { report="${report}$1"$'\n'; }

for repo in "${BRAINS[@]}"; do
  [ -d "$repo/.git" ] || continue
  [ -f "$repo/.no-autocommit" ] && { say "$(stamp) SKIP  $repo (.no-autocommit)"; continue; }

  # Nothing to do?
  dirty=$(git -C "$repo" status --porcelain 2>/dev/null)
  unpushed=""
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      unpushed=$(git -C "$repo" log --oneline '@{u}..HEAD' 2>/dev/null)
    fi
  fi
  [ -z "$dirty" ] && [ -z "$unpushed" ] && continue

  name=$(basename "$repo")

  # Refuse to touch a repo mid-operation.
  gitdir=$(git -C "$repo" rev-parse --git-dir 2>/dev/null)
  for state in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD BISECT_LOG; do
    if [ -e "$repo/$gitdir/$state" ] || [ -e "$gitdir/$state" ]; then
      add_report "  ⏭  $name: mid-operation ($state) - left alone"
      say "$(stamp) SKIP  $repo (in $state)"
      continue 2
    fi
  done

  if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
    add_report "  ⏭  $name: detached HEAD - left alone"
    continue
  fi

  # ---- commit (only if there are working-tree changes) ----
  if [ -n "$dirty" ]; then
    git -C "$repo" add -A 2>/dev/null

    # Secret gate. No gitleaks installed => do NOT auto-commit; a silent gate is worse than none.
    if command -v gitleaks >/dev/null 2>&1; then
      if ! git -C "$repo" diff --cached --quiet 2>/dev/null; then
        if ! gitleaks protect --staged --no-banner --redact \
              --source "$repo" >/dev/null 2>&1; then
          git -C "$repo" reset -q 2>/dev/null
          add_report "  🛑 $name: SECRETS DETECTED - not committed, not pushed. Run: gitleaks protect --staged --source $repo"
          say "$(stamp) BLOCK $repo (gitleaks findings)"
          continue
        fi
      fi
    else
      git -C "$repo" reset -q 2>/dev/null
      add_report "  ⚠️  $name: gitleaks not installed - refusing to auto-commit (install gitleaks or commit manually)"
      say "$(stamp) BLOCK $repo (no gitleaks)"
      continue
    fi

    if git -C "$repo" diff --cached --quiet 2>/dev/null; then
      git -C "$repo" reset -q 2>/dev/null
    else
      n=$(git -C "$repo" diff --cached --name-only | wc -l | tr -d ' ')
      files=$(git -C "$repo" diff --cached --name-only | head -8 | sed 's/^/  - /')
      more=""
      [ "$n" -gt 8 ] && more=$'\n'"  - ... and $((n-8)) more"
      msg="brain: auto-commit ${n} file(s) from Claude Code session

Committed automatically by the brain-autocommit Stop hook, so the remote is
never behind what a session wrote into this brain.

${files}${more}"
      if git -C "$repo" commit -q -m "$msg" 2>>"$LOG"; then
        add_report "  ✅ $name: committed $n file(s)"
        say "$(stamp) COMMIT $repo ($n files)"
      else
        add_report "  ⚠️  $name: commit failed (see $LOG)"
        continue
      fi
    fi
  fi

  # ---- push ----
  if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    git -C "$repo" fetch -q origin 2>/dev/null
    if [ -n "$(git -C "$repo" log --oneline 'HEAD..@{u}' 2>/dev/null)" ]; then
      if ! git -C "$repo" pull --rebase -q 2>>"$LOG"; then
        git -C "$repo" rebase --abort 2>/dev/null
        add_report "  ⚠️  $name: remote moved and rebase conflicted - commit is LOCAL, resolve by hand"
        continue
      fi
    fi
    if git -C "$repo" push -q origin "$branch" 2>>"$LOG"; then
      add_report "  ⬆️  $name: pushed to origin/$branch"
      say "$(stamp) PUSH  $repo -> origin/$branch"
    else
      add_report "  ⚠️  $name: push failed (see $LOG)"
    fi
  else
    if git -C "$repo" push -q -u origin "$branch" 2>>"$LOG"; then
      add_report "  ⬆️  $name: pushed + set upstream origin/$branch"
    else
      add_report "  ⚠️  $name: no upstream and push failed - commit is local (see $LOG)"
    fi
  fi
done

if [ -n "$report" ]; then
  printf 'Brain repos synced automatically:\n%s' "$report"
fi
exit 0
