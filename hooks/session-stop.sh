#!/usr/bin/env bash
ARTIFACTS="$HOME/.claude/artifacts"

if [ -f "$ARTIFACTS/iteration.json" ]; then
  STATUS=$(grep -o '"status":"[^"]*"' "$ARTIFACTS/iteration.json" | cut -d'"' -f4)
  # Don't overwrite a clean completion
  if [ "$STATUS" != "done" ]; then
    echo "{\"round\":0,\"status\":\"interrupted\",\"phase\":\"$STATUS\"}" > "$ARTIFACTS/iteration.json"
  fi
else
  echo '{"round":0,"status":"interrupted","phase":"unknown"}' > "$ARTIFACTS/iteration.json"
fi
