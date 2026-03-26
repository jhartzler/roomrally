#!/usr/bin/env bash
# Claude Code PreToolUse hook: prevent git commits on main/master
# Fires before Bash tool when command looks like a git commit

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check git commit commands
if [[ ! "$COMMAND" =~ ^git[[:space:]]+commit ]] && [[ ! "$COMMAND" =~ \&\&[[:space:]]*git[[:space:]]+commit ]]; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "BLOCKED: You are on the main branch. Create a feature branch first (git checkout -b <branch-name>). This project has branch protection - direct commits to main will be rejected."
    }
  }'
fi
