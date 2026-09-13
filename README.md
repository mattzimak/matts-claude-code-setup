# Matt's Claude Code setup

The Claude Code setup I run across three companies, packaged so a blank Claude Code can become it in about five minutes.

It is an onboarding, not a reading list. You install one plugin, run one command, answer a few questions, and Claude sets itself up: the hooks, the operating rules, and the protective settings, adapted to how you work. Then it runs a self-test to prove every piece works.

## Install

In Claude Code:

```
/plugin marketplace add mattzimak/matts-claude-code-setup
/plugin install matts-setup@mattzimak
```

Then start a new session and run:

```
/matts-setup:onboard
```

That is the whole install. Requires `jq`. Onboarding checks for it and tells you how to install it if it is missing.

## What onboarding does

Onboarding is a skill Claude runs for you. It only ever starts when you ask for it, never on its own.

1. **Checks your machine** for `jq` (required), `gitleaks` and `npx` (each needed for one optional feature).
2. **Asks at most two rounds of questions**, each with a recommended answer, so agreeing is one click. Is this one project or a multi-domain workspace? Any brand names that must always be spelled a certain way? Should knowledge repos auto-commit? Notifications on or off?
3. **Writes your answers** to `~/.claude/matts-setup/config.json`. Every hook reads that one file, so nothing you change later means editing a script.
4. **Merges two protections into your own settings**, showing you the change before it writes: transcripts kept for 365 days instead of 30, and a block on Claude reading `.env` and private key files. It backs the file up first and keeps every rule you already had.
5. **Adds the operating rules** to your `CLAUDE.md`, inside marker comments, using a script rather than a model edit, so running onboarding again updates them in place and never duplicates them.
6. **Runs the self-test** and shows you every result.
7. **Reports** what is now active, every file it touched, and exactly how to undo each change.

Run `/matts-setup:onboard` again any time to change an answer.

## What you get

| Hook | When | Effect | Default |
|---|---|---|---|
| Evidence audit | every prompt | Every progress report must point to a real tool result | on |
| Docs first | prompt names a fast-moving tool | Read current docs before answering, not training memory | on, always covers Claude Code |
| Execute yourself | prompt about setup, deploys, keys | Try it, try it another way, show the command, before handing anything off | on |
| Domain router | prompt matches one of your domains | Read that domain's `CLAUDE.md` first | on once you add domains |
| Brand casing | Claude writes a file | Flags a brand or name in the wrong form | on once you add names |
| Setup log | Claude edits your setup | Reminds it once per session to record what changed | on |
| Skill telemetry | a skill runs | Logs which skills fire, so you can prune the ones that never do | on |
| Plan to PDF | a plan is saved under `plans/` | Writes a PDF next to it | on, needs `npx` |
| Notification | Claude finishes | Desktop notification | on, macOS or Linux |
| Root hygiene | a file is created in the workspace root | Denies the write and says where it belongs | **opt-in** |
| Knowledge-repo auto-commit | Claude finishes | Commits and pushes your knowledge repos, gated by gitleaks | **opt-in** |

The last two are off until onboarding switches them on, because one blocks writes and the other pushes to git remotes without asking each time. Neither should ever turn itself on.

Plus two skills: **`onboard`**, which only you can start, and **`operating-rules`**, which Claude consults when it plans work, reports progress or decides whether to ask you something.

## The one idea

**Instructions drift. Hooks do not.**

`CLAUDE.md` loads at the start of a session and then competes for attention with everything else. Over a long session a rule written there can simply stop being followed. A hook fires on an event, every time, however long the session has run.

That gives a clean line for where every rule belongs:

- **If an event can detect it, make it a hook.** A file written to the wrong place, a prompt that mentions a tool, a brand misspelled in copy.
- **If it needs judgment, write it down.** "Is this plan still ambiguous?" cannot be detected by any event, so it lives in the operating rules.

This setup is that line applied case by case.

## Why each part exists

Every piece here was added after something went wrong.

**Transcripts kept for 365 days.** Claude Code deletes session transcripts after 30 days by default. I found out when it deleted the session that had built my personal website. The evidence was an identical cutoff exactly 30 days back across five unrelated local folders, with nothing older surviving anywhere, and no way to recover it. Two things I observed but have not seen documented: the sweep appeared to key on when a transcript was last modified rather than when the session started, and it did not appear to reach into per-session subagent folders.

**Brand casing lint.** A full client outreach pack shipped with the brand in the wrong casing, even though the rule already existed in two places: the assistant's memory and the client's knowledge base. Written rules get missed. A hook fires every time. It warns rather than blocks, because by the time a file is written the useful thing is to say exactly what to fix.

**Execute yourself.** The most common failure in agent work is not a missing capability. It is the agent assuming a limit instead of testing it, or reading one refused command as proof the whole goal is blocked, and then telling you to go do it by hand.

**Domain router.** A per-domain `CLAUDE.md` only loads when Claude reads a file in that folder, so working from a workspace root means the rules are never in context. The media route checks `docker image` and `favicon` before it checks `image`, so an infrastructure prompt never gets routed to an image-generation skill.

**Auto-commit.** The first version wrote its log to the current directory, which was inside the repo it was syncing, so it committed its own log. The log now lives outside every repo. It also refuses to commit at all if gitleaks is missing, on the principle that a silent safety gate is worse than none.

**Secrets deny list.** A rule saying "never read `.env`" is advice; a permission rule is enforced. The list covers nested `.env` files too, because subfolder repos carry their own and `Read(.env)` only protects the root.

## Rules for writing hooks

What building these taught me.

1. **Always exit 0.** A hook that errors must never block the session it is watching.
2. **Stay silent unless it matters.** A hook that talks on every prompt trains everyone to ignore it.
3. **Check negative cases before positive ones.** Broad keywords collide across domains.
4. **Deny when the damage can still be prevented; warn when it is already done.**
5. **Nest `additionalContext` inside `hookSpecificOutput`.** At the top level it is [silently ignored](https://code.claude.com/docs/en/hooks-guide), so the hook runs, exits cleanly, and does nothing.
6. **Keep logs outside whatever the hook acts on.**
7. **Fire once when once is enough**, with a flag file keyed on the session id.
8. **Test the silent cases, not only the firing ones.** Half a hook's value is what it correctly ignores.
9. **Do not read regex config with jq's `@tsv`.** It doubles backslashes, so `\bAcme\b` silently matches nothing. This setup joins fields on a unit separator instead.
10. **Distrust a green test run.** A check that received no input passes every silent case for the wrong reason. Plant a deliberate bug and make sure the suite catches it.

## How it was verified

- The plugin and marketplace manifests pass `claude plugin validate`.
- It was installed into a **blank Claude Code** (an empty config directory): marketplace added, plugin installed and enabled, all 15 scripts still executable afterwards.
- The self-test passes 28 of 28, run from the installed copy rather than the source.
- The self-test itself was checked by planting two bugs, a router that always fires and a brand lint that never does. It caught both.
- In a **live session**, Claude Code's own debug log shows the plugin loading, both skills registering, and the evidence-audit and docs-first hooks injecting their context on a real prompt.

Run the self-test yourself at any time:

```bash
bash ~/.claude/plugins/cache/mattzimak/matts-setup/*/scripts/selftest.sh
```

## Undo

Onboarding tells you each of these with your exact paths. In general:

- Restore the settings backup it made: `~/.claude/settings.json.bak.<timestamp>`.
- Delete `~/.claude/matts-setup/`.
- Remove the block between the `matts-setup:rules` markers in your `CLAUDE.md`.
- `/plugin uninstall matts-setup`.

## License

MIT. See [LICENSE](LICENSE).
