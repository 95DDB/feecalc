#!/usr/bin/env bash
# Shared helpers for hooks. Source this file; do not run it.
# A hook reads the event as JSON on stdin. Exit 2 blocks the action and sends
# stderr to the agent. Exit 0 with no output lets the normal flow continue.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

block() { echo "$1" >&2; exit 2; }

# ask <reason>: pause the action until the person at the keyboard approves it
ask() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "ask", permissionDecisionReason: $r}}'
  exit 0
}

# rel_path <path>: path relative to the project root
rel_path() {
  local p="$1"
  [[ "$p" == "$PROJECT_DIR"/* ]] && p="${p#"$PROJECT_DIR"/}"
  echo "${p#./}"
}

current_branch() {
  echo "${HL_CURRENT_BRANCH:-$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)}"
}
