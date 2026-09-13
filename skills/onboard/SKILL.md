---
name: onboard
description: Set up Matt Zimak's Claude Code setup for this user - a short interview, then config, safe settings merge, operating rules and a self-test. Run once after installing the plugin, and again any time to change answers.
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/selftest.sh)
---

# Onboard: adapt Matt's Claude Code setup to this user

You are onboarding someone onto a working Claude Code setup. The hooks are already
installed with the plugin, but several of them do nothing until they know who this
user is. Your job is to find out, write it down, apply the settings a plugin cannot
apply itself, and prove it all works. Do the work yourself; ask only for things only
the user can answer.

Everything this skill changes is listed in the final report, with how to undo it.

## Step 1 - Preflight

Run these and report what is present:

```bash
command -v jq && jq --version
command -v gitleaks && gitleaks version
command -v npx && npx --version
uname -s
```

- `jq` is **required**. Every hook uses it. If it is missing, stop and give the install
  command for this platform (`brew install jq`, or `apt install jq`), then continue once
  it is installed.
- `gitleaks` is needed only for knowledge-repo auto-commit. Without it, that feature stays off.
- `npx` is needed only for turning plans into PDFs. Without it, that hook quietly does nothing.

Check whether a previous run left a config, so answers can be kept:

```bash
cat ~/.claude/matts-setup/config.json 2>/dev/null || echo "no existing config"
```

If one exists, tell the user you will keep its answers as the defaults.

## Step 2 - Interview

Ask with the AskUserQuestion tool, in **at most two batches of up to four questions**.
Put the recommended option first in each question. Never pad to a count, and never ask
anything you can find out yourself.

**Batch 1 - always ask:**

1. **Workspace shape.** "One project" (recommended for most people: domain routing and root
   hygiene stay off) or "A workspace with several domains, each with its own CLAUDE.md"
   (turns on domain routing, and offers root hygiene).
2. **Names to protect.** "None" (recommended), or "Yes, brands or names that must always be
   written a specific way". If yes, collect each one in the next batch.
3. **Knowledge repos.** "Off" (recommended). Or "Auto-commit and push these repos when Claude
   finishes", which writes to git remotes unattended. Only offer "on" if gitleaks was found
   in Step 1, and say plainly that it pushes without asking each time.
4. **Notifications.** "Detect my platform" (recommended) or "Off".

**Batch 2 - only for the answers that need detail:**

- For **several domains**: for each domain, its name, the path to its CLAUDE.md, and a few
  keywords that signal that kind of work. Look at the actual folders first and propose them,
  so the user confirms rather than types. Use `\b` word boundaries in keywords, for example
  `\blinkedin\b|\bcaption\b`, so short words do not match inside longer ones.
- Offer **root hygiene** for a multi-domain workspace: on or off, and which files may live in
  the root. Default the allow list to the canonical files you can actually see in the root.
- For **names**: the correct form, the wrong forms seen in practice, and a short lowercase
  trigger word. Build `bad` as a case-sensitive regex, for example `\bAcme [Rr]ockets\b`.
- For **knowledge repos**: the absolute paths. Confirm each one is a git repo with a remote
  before adding it (`git -C <path> remote -v`).
- **Tools to ground in current docs** beyond Claude Code, which is always on. Only ask if the
  user's work obviously involves a fast-moving tool.

## Step 3 - Write the config

Write `~/.claude/matts-setup/config.json`, following the shape in
`${CLAUDE_PLUGIN_ROOT}/templates/config.example.json`. Omit any key the user did not
switch on; every hook treats a missing key as "off".

Validate it before moving on:

```bash
mkdir -p ~/.claude/matts-setup
jq -e . ~/.claude/matts-setup/config.json >/dev/null && echo "config is valid JSON"
```

## Step 4 - Merge the settings a plugin cannot set

A plugin may only set `agent` and `subagentStatusLine` in its own settings, so two protections
have to go into the user's own `~/.claude/settings.json`:

- **`cleanupPeriodDays: 365`.** Claude Code deletes session transcripts after 30 days by default.
  That once deleted a session that had built an entire website, with no way back.
- **A `permissions.deny` list** blocking reads of `.env` files, including nested ones in subfolder
  repos, and private key files.

Show the result first, without writing anything:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/merge-settings.sh --dry-run
```

Explain the two changes in plain words, confirm with the user, then apply:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/merge-settings.sh
```

It backs up the file first, keeps every rule the user already had, never lowers a higher
retention value, and changes nothing on a second run. Note the backup path it prints.

## Step 5 - Add the operating rules

Plugins cannot load a CLAUDE.md into context, so the operating rules only take effect once they
are in the user's own. Ask where they want them: the **user-level** file `~/.claude/CLAUDE.md`
(recommended, applies everywhere) or this **project's** `CLAUDE.md`.

Append the contents of `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md`. It starts and ends with
marker comments. If the markers are already present, **replace the block between them** instead of
appending a second copy, so re-running onboarding never duplicates it. Never touch anything outside
the markers.

## Step 6 - Prove it works

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/selftest.sh
```

It runs against a throwaway config and workspace, so it never touches the user's real files. Every
line must say PASS. If anything fails, show the output, fix the cause, and run it again. Do not report
success on a failing test.

Then check the user's real config actually drives the hooks, using a prompt matched to one of their
answers:

```bash
echo '{"prompt":"<a prompt that should match one of their domains>"}' \
  | ${CLAUDE_PLUGIN_ROOT}/scripts/domain-router.sh
```

## Step 7 - Report

End with a short report:

- **What is now active**, as a list, including which opt-in features were left off and why.
- **Every file changed**, with the settings backup path.
- **How to undo**: restore the settings backup; delete `~/.claude/matts-setup/`; remove the block
  between the markers in CLAUDE.md; `/plugin uninstall matts-setup`.
- **One thing to do next**: start a new session, because hooks and CLAUDE.md load at session start.

Re-run `/matts-setup:onboard` any time to change an answer.
