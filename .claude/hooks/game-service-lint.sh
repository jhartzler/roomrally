#!/usr/bin/env bash
# Claude Code PostToolUse hook: lint game service modules after edit
# Checks for: scattered broadcasts, broadcasts inside locks, missing with_lock

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

# Only check game service files
if [[ -z "$FILE_PATH" ]] || [[ ! "$FILE_PATH" =~ app/services/games/ ]] || [[ ! "$FILE_PATH" =~ \.rb$ ]]; then
  exit 0
fi

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

VIOLATIONS=""

# Check for GameBroadcaster calls outside of broadcast_all and game_started methods
# game_started legitimately calls broadcasters directly (game object may not exist yet)
# Uses depth tracking to handle nested blocks (unless/if/do inside methods)
SCATTERED=$(awk '
  /def (self\.)?broadcast_all/ { in_allowed=1; depth=0 }
  /def self\.game_started/ { in_allowed=1; depth=0 }
  in_allowed && /\b(def |do\b|if |unless |case |begin |class |module )/ { depth++ }
  in_allowed && /^[[:space:]]*end\b/ {
    depth--
    if (depth <= 0) { in_allowed=0; depth=0 }
  }
  !in_allowed && /GameBroadcaster\./ { print NR": "$0 }
' "$FILE_PATH" || true)
if [[ -n "$SCATTERED" ]]; then
  VIOLATIONS="${VIOLATIONS}BROADCAST VIOLATION - GameBroadcaster calls outside broadcast_all method (use broadcast_all as single exit point):\n${SCATTERED}\n\n"
fi

# Check for broadcast calls inside with_lock blocks
BROADCAST_IN_LOCK=$(awk '
  /with_lock/ { lock_depth++ }
  lock_depth > 0 && /^[[:space:]]*end/ { lock_depth-- }
  lock_depth > 0 && /broadcast_all/ { print NR": "$0 }
' "$FILE_PATH" || true)
if [[ -n "$BROADCAST_IN_LOCK" ]]; then
  VIOLATIONS="${VIOLATIONS}CONCURRENCY VIOLATION - broadcast_all called inside with_lock (broadcast OUTSIDE the lock):\n${BROADCAST_IN_LOCK}\n\n"
fi

if [[ -n "$VIOLATIONS" ]]; then
  jq -n --arg ctx "$(echo -e "$VIOLATIONS")" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("GAME SERVICE LINT VIOLATIONS DETECTED. Fix these before proceeding:\n\n" + $ctx + "Rules: Use broadcast_all as the single exit point for all broadcasting. Never call GameBroadcaster directly outside broadcast_all. Always broadcast OUTSIDE with_lock blocks.")
    }
  }'
fi
