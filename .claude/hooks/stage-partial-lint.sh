#!/usr/bin/env bash
# Claude Code PostToolUse hook: lint stage partials after edit
# Checks for: px/rem sizing, inline animations, firstElementChild assumptions

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

# Only check stage partials
if [[ -z "$FILE_PATH" ]] || [[ ! "$FILE_PATH" =~ _stage_ ]] || [[ ! "$FILE_PATH" =~ \.html\.erb$ ]]; then
  exit 0
fi

# Skip if file doesn't exist (was deleted)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

VIOLATIONS=""

# Check for px/rem sizing in stage partials (should use vh)
PX_MATCHES=$(grep -nE '(text-[0-9]xl|text-(xs|sm|base|lg)|p-[0-9]+|m-[0-9]+|gap-[0-9]+|space-[xy]-[0-9]+|w-[0-9]+|h-[0-9]+)' "$FILE_PATH" | grep -vE '(text-vh-|shrink-|flex-|grow-|rounded-|border-|opacity-|z-|col-|row-|grid-|order-)' || true)
if [[ -n "$PX_MATCHES" ]]; then
  VIOLATIONS="${VIOLATIONS}STAGE VIEW VIOLATION - Fixed sizing detected (use vh units instead):\n${PX_MATCHES}\n\n"
fi

# Check for inline animation classes (should use stage-transition controller)
ANIM_MATCHES=$(grep -nE 'animate-' "$FILE_PATH" | grep -v 'data-controller.*stage-transition' | grep -v '{#.*animate' || true)
if [[ -n "$ANIM_MATCHES" ]]; then
  VIOLATIONS="${VIOLATIONS}STAGE VIEW VIOLATION - Inline animation classes (use stage-transition Stimulus controller):\n${ANIM_MATCHES}\n\n"
fi

if [[ -n "$VIOLATIONS" ]]; then
  # Return context to Claude so it can self-correct
  jq -n --arg ctx "$(echo -e "$VIOLATIONS")" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("STAGE PARTIAL LINT VIOLATIONS DETECTED in this file. Fix these before proceeding:\n\n" + $ctx + "Rules: Stage views must use text-vh-* classes and p-[Nvh]/m-[Nvh] spacing. Animations must use the stage-transition Stimulus controller, not inline animate-* classes.")
    }
  }'
fi
