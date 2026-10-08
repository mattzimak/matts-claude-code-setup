# Setup log

Dated changes to my Claude Code setup, newest first. Companion to the plugin and to [matts-mac-setup](https://github.com/mattzimak/matts-mac-setup). Format: `## YYYY-MM-DD - Title` + **What / Why / How**.

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
