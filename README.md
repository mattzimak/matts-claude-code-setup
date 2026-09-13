# Claude Code setup

The hooks, settings and rules I actually run in Claude Code across three companies, with the failure behind each one. Every hook in `hooks/` is tested against the cases where it should fire and the cases where it should stay silent.

This is not a list of what exists. It is one working setup, and the reasoning that shaped it.

## The one idea

**Instructions drift. Hooks do not.**

`CLAUDE.md` is loaded at the start of a session and then competes for attention with everything else in context. Over a long session, a rule written there can simply stop being followed. A hook fires on an event, every time, regardless of how long the session has run.

That gives a clean dividing line for where any rule belongs:

- **If an event can detect it, make it a hook.** A file written to the wrong folder, a prompt that mentions a tool, a brand misspelled in copy - all detectable, all hooks.
- **If it needs judgment, keep it in `CLAUDE.md`.** "Is this plan still ambiguous?" cannot be detected by any event, so it stays a written rule.

Most of what follows is that line applied case by case.

## Contents

- [Hooks](#hooks)
- [Rules for writing hooks](#rules-for-writing-hooks)
- [Settings](#settings)
- [Never losing a session](#never-losing-a-session)
- [Secrets](#secrets)
- [Rules that stay in CLAUDE.md](#rules-that-stay-in-claudemd)
- [Install](#install)

## Hooks

| Hook | Event | Effect | What it prevents |
|---|---|---|---|
| [`evidence-audit-directive.sh`](hooks/evidence-audit-directive.sh) | UserPromptSubmit | injects | Progress reports that claim work nobody verified |
| [`docs-first-reminder.sh`](hooks/docs-first-reminder.sh) | UserPromptSubmit | injects | Answering fast-moving tools from stale training memory |
| [`domain-router.sh`](hooks/domain-router.sh) | UserPromptSubmit | injects | Domain rules being invisible when you work from the workspace root |
| [`root-hygiene.sh`](hooks/root-hygiene.sh) `guard` | PreToolUse (Write) | **denies** | Stray files accumulating in the workspace root |
| [`root-hygiene.sh`](hooks/root-hygiene.sh) `sweep` | SessionStart | injects | Strays that arrived another way, via a shell or Finder |
| [`brand-casing-lint.sh`](hooks/brand-casing-lint.sh) | PostToolUse (Edit, Write) | warns | A brand shipping in the wrong casing |
| [`cc-setup-log-reminder.sh`](hooks/cc-setup-log-reminder.sh) | PostToolUse (Edit, Write) | injects once | Setup changes nobody can reconstruct later |
| [`plan-to-pdf.sh`](hooks/plan-to-pdf.sh) | PostToolUse (Write) | side effect | Plans that only exist as Markdown nobody opens |
| [`skill-usage-logger.sh`](hooks/skill-usage-logger.sh) | PreToolUse (Skill) | logs | Installing hundreds of skills with no idea which ones fire |
| [`brain-autocommit.sh`](hooks/brain-autocommit.sh) | Stop | commits and pushes | Knowledge written into a repo that never reaches the remote |
| notification (see [`user-settings.json`](settings/user-settings.json)) | Stop | side effect | Watching a terminal to find out a long task finished |

### Evidence audit

Injects a short directive into every prompt: audit each claim against a tool result from this session, report only what you can point to evidence for, and say plainly when a step failed. It is the cheapest hook here and the one I would install first. Its value is not that the model lies, it is that over a long session "I'll check that" quietly becomes "that's done".

### Docs first

When a prompt names a tool whose surface changes often, it injects a reminder to read current official documentation before answering, here through the Context7 MCP server. Topics are independent `if` blocks, so a prompt naming two tools gets both reminders. Claude Code itself is the first topic, because its configuration changes faster than any model's training data.

### Domain router

In a workspace with a `CLAUDE.md` per domain, those files load lazily: only when you `cd` in, or when Claude reads a file under that folder. Work from the root and their rules are never in context. The router injects "read this domain's `CLAUDE.md` first" when a prompt looks like that domain's work.

Two details carry most of the value. **Negative guards come before positive matches**: the media route checks `docker image`, `favicon` and `og-image` first, so an infrastructure prompt never gets routed to an image-generation skill. And **some routes exist to guarantee a skill fires**, not a file gets read, because skill activation is model judgment and a hook is not.

The file also carries an **execute-yourself** block. The most common failure in agent work is not missing capability. It is the agent assuming a limit instead of testing it, or reading one refused command as proof the whole goal is blocked, then telling you to go do it by hand. The block requires any handoff to have been attempted, attempted more than one way, and reported with the exact command and its output.

### Root hygiene

A guard and a sweep, because each catches what the other cannot. The **guard** runs at PreToolUse and denies creating a new file directly in the workspace root, with a reason that tells the model where to put it instead. The **sweep** runs at SessionStart and reports strays that got there without the Write tool, dragged in from Finder or created by a shell command. The guard stops new mess; the sweep finds existing mess.

### Brand casing lint

Built after a full client outreach pack shipped with the brand in the wrong casing, even though the rule already existed in two places. It warns rather than denies, because by PostToolUse the file is already written and the useful move is to say exactly what to fix in the same turn. It skips the files that legitimately quote the wrong forms, or it would nag about its own documentation.

### Setup change log

Fires when a session edits `.claude/`, `CLAUDE.md` or `.mcp.json`, and reminds the model to record what changed and why before the session ends. It fires **once per session**, using a flag file keyed on the session id, so ten edits produce one reminder rather than ten.

### Skill telemetry

A PreToolUse hook on the `Skill` tool that appends one line per invocation to a local log. After a few weeks, [`skill-usage-report.sh`](hooks/skill-usage-report.sh) ranks skills by use, and the ones that never appear are either dead weight to remove or good skills with a trigger description too weak to fire. It is registered in `settings.local.json`, because personal telemetry is personal state and should not be committed.

### Auto-commit knowledge repos

The riskiest hook here, because it writes to git remotes unattended, so it is deliberately conservative. On Stop it walks a list of knowledge repos and commits and pushes anything dirty, but only after `gitleaks protect --staged` passes. A finding skips that repo entirely. If gitleaks is not installed it refuses to commit at all, on the principle that a silent gate is worse than no gate. It never force-pushes, never rewrites history, never touches a repo mid-rebase, and aborts a conflicting rebase rather than resolving it, leaving the commit local for a person.

One bug from testing is kept in the comments on purpose: the first version wrote its log to `$PWD`, which was inside the repo it was syncing, so it committed its own log. The log path is now absolute and outside every repo.

## Rules for writing hooks

Distilled from building the hooks above.

1. **Always exit 0.** A hook that errors must never block the session it observes. Wrap best-effort work so failure is silent.
2. **Silent unless it matters.** Emit nothing on no match. A hook that talks on every prompt trains you, and the model, to ignore it.
3. **Negative guards before positive matches.** Broad keywords collide across domains. Exclude the known false positives first.
4. **Deny when the damage can still be prevented, warn when it is already done.** PreToolUse can stop a write; PostToolUse can only report one.
5. **Nest `additionalContext` inside `hookSpecificOutput`.** At the top level it is silently ignored, per the [hooks guide](https://code.claude.com/docs/en/hooks-guide). The failure mode is a hook that runs, exits cleanly, and does nothing.
6. **Log outside whatever you are acting on.** See the auto-commit bug above.
7. **Fire once when once is enough.** A flag file keyed on `session_id` turns repeated events into a single reminder.
8. **Use `$CLAUDE_PROJECT_DIR` in project hook paths**, so a hook still resolves after the session changes directory.
9. **Test the silent cases, not just the firing ones.** Half the value of a hook is what it correctly ignores.

## Settings

[`settings/settings.json`](settings/settings.json) is the project file; [`settings/user-settings.json`](settings/user-settings.json) is the machine-wide one. Keep genuinely global behaviour at user level and everything project-specific in the project.

### Deny secret reads at the harness level

A `CLAUDE.md` rule saying "never read `.env`" is advice. A `permissions.deny` entry is enforced. Two things matter in the list:

- **Include the nested globs** (`**/.env`, `**/.env.*`). Subfolder repos inside a workspace often carry their own `.env`, and `Read(.env)` alone only covers the root.
- **Cover key material, not just env files**: `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`.

### Path-scoped rules

[`rules/dev-product.md`](rules/dev-product.md) shows a rule with `paths` frontmatter. It loads only when Claude reads a file matching the glob, [not on every tool call](https://code.claude.com/docs/en/memory). That makes it the right place for a thin pointer to a domain's `CLAUDE.md`. Keep these as pointers, never copies, because a duplicated rule drifts from its source within weeks.

It complements the domain router: the router keys on the words in the prompt, the rule keys on the files actually touched, so it still catches domain work that began with a prompt the router missed.

## Never losing a session

Claude Code deletes session transcripts after `cleanupPeriodDays`, which [defaults to 30](https://code.claude.com/docs/en/settings-reference). I did not know that until it deleted the session that had built my personal website.

What the evidence showed: an identical last-modified cutoff, exactly 30 days back, across five unrelated local stores, with no surviving transcript older than it anywhere. A manual deletion cannot produce the same cutoff in five directories. Two further things I observed but have not seen documented, so treat them as observations: the sweep appeared to key on last-modified time rather than session start, which is why sessions begun in the same window survived if they had later been resumed; and it did not appear to recurse into per-session subagent folders, which is why their files outlived their parents. No recovery path worked.

The defence has three layers:

1. **Raise the retention.** `"cleanupPeriodDays": 365` in the user settings. Zero fails validation, so use a large number rather than trying to disable it.
2. **Archive outside the reach of the sweep.** A nightly scheduled job gzips every transcript into a folder outside `~/.claude`, incrementally, never deleting. It writes to a partial file and moves it into place, so an interrupted run cannot leave a truncated archive, and a restore was verified byte-identical with SHA-256.
3. **Distil what matters while it is fresh.** A skill writes a context file into the project folder: what it is, current state and how it was verified, decisions and their reasoning, open items, and the exact commands. Raw transcripts are recoverable but unreadable; the distilled file is what a future session actually uses.

## Secrets

The pattern that made secrets stop being a recurring problem:

- **One source of truth.** A password manager holds every credential.
- **One sync script, and nothing else, talks to it.** It writes a local `.env` cache in a single pass, so no session ever needs the vault unlocked, a fingerprint, or a system password.
- **The cache is fully regenerable.** The script derives its managed key list from its own template, so there is no second list to fall out of date. It reports drift, meaning keys in `.env` with no vault entry, and the target is zero. A committed, names-only manifest records what exists without recording any value.
- **Agents never read `.env`.** Small consumer scripts load it internally and call the API, so the model runs `api.sh get users/me` and never sees a token. Combined with the deny list above, a leak needs both a missing rule and a bypassed wrapper.
- **No runtime fallbacks to the vault.** A wrapper that silently falls back to a live vault read fails in confusing ways once the vault layout changes. Fail fast and point at the sync script instead.

The failure that prompted the rewrite: the old sync used a hand-maintained key list that had drifted, so it re-appended the same block on every run until `.env` held 22 copies of several keys.

## Rules that stay in CLAUDE.md

These need judgment, so no event can enforce them.

**Clarify by question, not by quota.** Resolve ambiguity that would fork the build with batched questions, at most four at a time, each carrying a recommended default so agreeing costs one click. Never pad to a number: "ask at least ten questions" manufactures filler and trains rubber-stamping. Sort unknowns by type rather than count. Preferences only the person holds, ask. Facts the code or docs can answer, go and find them. Unknowns nobody can see yet, build a thin first slice that surfaces them cheaply. Stop the moment only safe defaults remain, and say which defaults you took.

**Keep exported plans current.** A plan revised after export gets re-exported to the same filename in the same session, so the saved copy never lags the version being executed. And export with the file-writing tool rather than a shell copy, because the PDF hook fires on Write and a `cp` silently produces a Markdown file with no PDF.

**Log every setup change, twice.** Every change to hooks, settings, skills or `CLAUDE.md` gets an entry saying what changed, why it is good practice, and which files, written so a reader with no context could replicate it. The change-log hook above is the backstop; this is the rule it enforces.

## Install

Copy what you want rather than the whole thing. Each hook is independent.

```bash
mkdir -p .claude/hooks
cp hooks/root-hygiene.sh hooks/domain-router.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

Then merge the matching entries from [`settings/settings.json`](settings/settings.json) into your own `.claude/settings.json`. The hooks need `jq`; `brain-autocommit.sh` also needs `gitleaks`; `plan-to-pdf.sh` uses `npx md-to-pdf`.

Edit the parts that are mine. The domain names and keywords in `domain-router.sh`, the brand list in `brand-casing-lint.sh`, and the repo list in `brain-autocommit.sh` are examples, not defaults.

Test the silent cases before you trust a hook:

```bash
echo '{"prompt":"rebuild the docker image"}' | .claude/hooks/domain-router.sh   # expect no output
echo '{"prompt":"generate a photo of a cabin"}' | .claude/hooks/domain-router.sh # expect JSON
```

When checking hook output in a script, pipe it with `printf '%s'` rather than `echo`. `echo` can interpret backslash escapes inside the message and hand `jq` broken JSON, which makes a working hook look broken.

## License

MIT. See [LICENSE](LICENSE).
