# Setup log

Dated changes to my Claude Code setup, newest first. Companion to the plugin and to [matts-mac-setup](https://github.com/mattzimak/matts-mac-setup). Format: `## YYYY-MM-DD - Title` + **What / Why / How**.

## 2026-07-19 - A setup change log, paired with a wiki sync and a reminder hook

**What:** A dated change log for every Claude Code setup change (hooks, skills, settings, permissions), paired with a small script that mirrors each entry into a wiki page as a dated block, plus a `PostToolUse` hook that fires a reminder whenever a setup file gets edited.

**Why:** Setup knowledge dies in chat scrollback the moment the session ends. Writing it down twice - once in a git-tracked log for diff history, once in a shared wiki page for a quick, non-technical read - means the next session (or the next person) doesn't have to rediscover a hook by reading its source.

**How:** Keep one markdown log per machine or workspace, newest entry first, with a fixed template (what changed, why it's a good practice, which files). A small sync script posts the same content to your wiki or notes tool as a new dated block under a parent page. A `PostToolUse` hook matching edits to hook scripts, settings files or skill files prints a reminder to log the change - treat it as a backstop, since the actual logging is still a stated convention, not something the hook can enforce by itself.

## 2026-07-19 - Root hygiene: a guard hook plus a sweep hook

**What:** Two hooks that stop stray files from piling up in a repo root. A `PreToolUse` hook on `Write` denies creating any new file directly in the root unless it's on a short allowlist (canonical top-level docs, dotfiles) - the deny reason tells the agent exactly where to write instead (a scratch directory, a staging folder, or the owning project folder), so it self-corrects in the same turn. A `SessionStart` hook sweeps the root for stray files that arrived outside the `Write` tool (shell commands, Finder drags, pasted screenshots) and flags them for routing at the start of the next session.

**Why:** Deny-at-write-time beats a post-hoc reminder, because the file never lands in the first place; the sweep catches the drops the guard can't see, since anything that didn't go through the `Write` tool is invisible to it. Each hook alone is incomplete: `SessionStart` alone just nags after the mess already exists, and `PreToolUse` alone misses every non-agent write.

**How:** The `PreToolUse` hook checks `tool_input.file_path` against the allowlist and, on a miss, returns a deny decision whose reason text names the correct destination. The `SessionStart` hook runs a glob sweep of the root and injects a routing reminder into context when it finds anything unexpected. State the same contract in your project instructions file too (root holds only canonical docs, folders and dotfiles, no numbered folder prefixes) so a human reading it gets the rule the hooks enforce.

## 2026-07-18 - Wiring a third-party skill pack into the domain that actually needs it

**What:** Installed a batch of third-party skills globally, then hard-coded their names into the project-instructions table for the one working area that needs them, instead of relying on each skill's own description to get picked up by name-matching.

**Why:** A skill installed globally is visible everywhere, but it only reliably fires on the task it's meant for if something routes to it by name. Once a skill listing grows large, only names (not every description) stay loaded in context, so unless a domain's own instructions explicitly mandate a skill, installing it buys you little beyond an occasional lucky match.

**How:** Install globally so the skill is available everywhere, then add its name to the "mandatory skills" table or list in whichever project-instructions file covers the domain it's meant for. Gotcha: a batch-install CLI may insist on installing one skill at a time and may refuse a skill whose frontmatter has no explicit `name` field.

## 2026-07-16 - Path-scoped rules, skill-usage telemetry, deny-list hardening

**What:** Three additions. (1) A set of path-scoped rule files that auto-load when a file matching their glob is read or edited - the file-access complement to a prompt-based routing hook. (2) A `PreToolUse` hook that logs every skill invocation to a local, gitignored log file, plus a small report script for which skills are actually firing. (3) The permissions deny-list hardened to match nested `.env` files (not just a root-level one), plus common certificate/key file extensions and SSH key files.

**Why:** A prompt-based routing hook only catches intent expressed in words; a lot of work starts by opening a file directly, so file-access-triggered rules are a complement, not a duplicate. Usage telemetry turns "which skills are actually used" from a guess into a report, so unused skills can be pruned with evidence instead of hunch. A deny-list rule written for only a root-level secrets file misses every nested repo or subfolder that carries its own copy.

**How:** Store rule files under a dedicated rules folder, each with a frontmatter block naming the glob(s) it should load for. Add a `PreToolUse` hook matching the skill-invocation tool, appending a timestamp + skill name line to a log file outside version control; a short script aggregates that log into counts. Extend permissions deny patterns from a literal filename to a recursive glob (`**/.env`), and add key/cert extensions (`*.p12`, `*.pfx`) and SSH private key paths explicitly - a deny-list that only covers the obvious top-level case gives false confidence.

## 2026-07-16 - A domain-router hook for a multi-area workspace

**What:** A `UserPromptSubmit` hook that detects which working domain a prompt is about (when a workspace is split into several separate areas, each with its own project-instructions file) and injects a reminder to read that domain's instructions file first, before acting.

**Why:** If you mostly work from the repo root rather than `cd`-ing into a subproject, that subproject's own instructions file never auto-loads - it only loads on `cd` or when a file inside it is touched. Without a backstop, a session can act on a domain's work without ever seeing that domain's conventions, skill requirements or constraints.

**How:** Write a keyword or regex match per domain (a handful of trigger words that reliably signal "this prompt is about domain X") and have the hook emit an `additionalContext` reminder naming the exact instructions file to read first. State the same routing table in your root instructions file too, so the hook is a backstop and not the only place the rule lives.

## 2026-07-16 - Evidence-audit directive hook (global)

**What:** A `UserPromptSubmit` hook, registered at the user-global level so it covers every project, that injects a short mandatory-verification directive into every prompt: audit each progress claim against an actual tool result from the session, flag anything unverified, and report a failure with its real output instead of claiming unproven success.

**Why:** Long or multi-step agentic turns are exactly where a model's running narration drifts from what it actually verified - "fantasy progress reports." A deterministic harness-level injection survives context compaction and long sessions in a way a one-time instruction in a project file doesn't, since it's re-injected on every single turn.

**How:** Keep the directive text in a small variable inside the hook script so changing the wording is a one-line edit. Register the script under `UserPromptSubmit` in your user-global settings (not a per-project settings file) so it applies everywhere, including ad hoc sessions outside any particular project. Removing the hook registration disables it instantly, with no change to the script needed.

## 2026-07-12 - Evaluating Composio's Tool Router for Claude Code

**What:** Looked at wiring Composio's Tool Router (one API surface across hundreds of app integrations) into Claude Code.

**Why:** Wanted broader third-party app coverage than the first-party connectors and existing automation platform already give, without hand-rolling an MCP server per app.

**How:** Composio needs to run as a Claude Code **plugin**, not a static `.mcp.json` MCP server entry - a plain server definition doesn't expose Tool Router's dynamic tool discovery correctly. Keep the API key in your secrets manager and inject it as an environment variable; `.mcp.json` should only ever hold `${ENV_VAR}` references, never a literal key. Because Tool Router overlaps with first-party connectors and whatever automation platform you already run, add its skills selectively rather than wholesale.

## 2026-07-10 - Two artifacts for web quality: a pre-ship checklist skill and a defect-finding audit workflow

**What:** Split "is this site good enough" into two separate tools instead of one: an affirmative pre-ship checklist skill that triggers on phrasing like "ship the site" or "is the site ready" and packages a fixed quality bar (weak-connection-first loading, compressed media, single-origin requests, accessibility, SEO), and a separate multi-agent workflow that audits an already-built site against the same bar looking for defects.

**Why:** A single skill or checklist tends to conflate two different jobs - confirming something is ready to ship versus hunting for what's currently broken - and ends up mediocre at both.

**How:** The checklist is a plain skill file with a trigger description tuned to pre-launch phrasing. The audit is a multi-agent workflow script, invoked so it can fan several review agents out in parallel instead of running everything serially. Write your quality bar once as a checklist doc, wrap it in a skill for the "about to ship" moment, and write a separate workflow for the "audit what already shipped" moment - reference both from your project's own quality-bar documentation so neither gets forgotten.

## 2026-07-08 - Plan-to-PDF hook: every plan or guide markdown gets an automatic PDF twin

**What:** A `PostToolUse` hook watching `Write` calls: whenever a markdown file lands in a `plans/` or `guides/` folder in any project, it automatically renders a sibling PDF next to it.

**Why:** Plans and guides get shared outside the terminal - email, chat, printed - far more often than other markdown, and a manual "now go export this" step gets skipped under time pressure.

**How:** The script reads `tool_input.file_path` from the hook's stdin JSON and path-filters on `*/plans/*.md` or `*/guides/*.md`. Converter chain, primary then fallback: `npx --yes md-to-pdf` wrapped in a hard `timeout` (its headless-Chromium backend can hang - never let a hook block the session indefinitely on a subprocess), falling back to a markdown-to-styled-HTML-to-PDF path if the primary fails. Register the script under `hooks.PostToolUse` with matcher `Write`, in either the user-global or a project `settings.json` depending on how widely you want it to apply.

## 2026-07-06 - Documentation-first hook: force current docs over model memory for fast-moving tools

**What:** A `UserPromptSubmit` hook that detects when a prompt touches a docs-gated topic and injects an instruction to consult a documentation MCP server (Context7) for current official docs instead of answering from training memory.

**Why:** Fast-moving tools change their APIs, menus and config keys often enough that a model's training-time knowledge goes stale within months. The failure mode is a confidently wrong answer about something that used to be true.

**How:** Add a documentation MCP server to `.mcp.json` (plus the matching `enabledMcpjsonServers` and a permissions allow-rule for its tools in `settings.json`). Write a script that greps the incoming prompt for topic keywords and, on a match, emits `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<directive>"}}` on stdout, then register it under `hooks.UserPromptSubmit`. Gate an additional topic later by adding one more keyword-matched block to the same script - no new hook needed.

## 2026-06-18 - Auto-open Finder (and the browser) for anything you need to look at or act on

**What:** A CLAUDE.md convention, not a hook (deciding what counts as a "deliverable" needs judgment a hook can't reliably make): every file a reply hands back gets revealed in Finder (`open -R "<file>"`) with the plain path printed alongside. Companion rule: whenever a task needs a manual step in some web console that can't be driven headlessly, give the deepest possible direct link to the exact page and open it in the browser for you.

**Why:** A generated file, or a "go click this setting" instruction, that isn't already open and waiting gets read once, then forgotten, then hunted for later. Removing that extra "now go find it yourself" step measurably raises the odds a handoff actually gets completed.

**How:** Add both rules as plain prose to your root CLAUDE.md - this is an instruction, not a hook. Cap it at once per distinct folder or URL per turn so it doesn't spam repeated opens for the same target. Also worth documenting, once, which link formats actually render as clickable in your editor of choice versus which need the Finder/browser fallback - in most editor webviews, binaries and folders have no working inline link at all, so the reveal-in-Finder step **is** the delivery for those.

## 2026-06-18 - Sound and notification when a turn finishes (global Stop hook)

**What:** A desktop notification with a distinct sound plays every time Claude Code finishes responding, in every project.

**Why:** Long agentic turns mean the terminal isn't the thing you're staring at the whole time; a sound cue turns "check back periodically" into "come back when you hear it."

**How:** Merge a `Stop` hook into your user-global `settings.json` - no script file needed, just an inline command. On macOS:

```json
{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"osascript -e 'display notification \"Task complete\" with title \"Claude Code\" sound name \"Frog\"' 2>/dev/null || true"}]}]}}
```

Any sound name from `/System/Library/Sounds` works. Delete the `Stop` block to disable.
