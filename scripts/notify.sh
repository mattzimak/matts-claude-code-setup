#!/usr/bin/env bash
# Stop hook - desktop notification when Claude finishes, so you are not watching
# a terminal to find out a long task is done.
#
# Config: "notify": "macos" | "linux" | "off"   (default: detect the platform)
# Always exits 0: a notification that fails must never block the session.

source "$(dirname "$0")/_config.sh"
mode="$(cfg_get '.notify')"
if [ -z "$mode" ]; then
  case "$(uname -s)" in Darwin) mode=macos ;; Linux) mode=linux ;; *) mode=off ;; esac
fi

case "$mode" in
  macos) osascript -e 'display notification "Task complete" with title "Claude Code" sound name "Frog"' 2>/dev/null ;;
  linux) command -v notify-send >/dev/null 2>&1 && notify-send "Claude Code" "Task complete" 2>/dev/null ;;
esac
exit 0
