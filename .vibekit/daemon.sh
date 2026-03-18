#!/bin/bash
# vibekit autonomous daemon — polls for open issues and runs /vb-build --once
# Installed by /vb-daemon install, managed by launchd (macOS) or cron (Linux)
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$PROJECT_ROOT" ] || exit 1

cd "$PROJECT_ROOT"

VIBEKIT_DIR="$PROJECT_ROOT/.vibekit"
LOG="$VIBEKIT_DIR/daemon.log"
LOCK="$VIBEKIT_DIR/daemon.lock"
MAX_LOG_LINES=2000

# Rotate log if too large
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt "$MAX_LOG_LINES" ]; then
  tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Lock — prevent overlapping runs
if [ -f "$LOCK" ]; then
  LOCK_PID=$(cat "$LOCK" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    log "Already running (pid $LOCK_PID) — skipping"
    exit 0
  fi
  rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Check gh auth
if ! gh auth status &>/dev/null 2>&1; then
  log "ERROR: gh not authenticated — daemon paused. Run: gh auth login"
  exit 1
fi

# Count open vibekit issues
OPEN_COUNT=$(gh issue list --label "vibekit" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
TOTAL=$((OPEN_COUNT + ARCH_COUNT))

log "Poll: vibekit=$OPEN_COUNT arch=$ARCH_COUNT total=$TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  log "No open issues — checking for launch gate"

  # Check if we should auto-launch
  BUG_COUNT=$(gh issue list --label "bug" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "1")
  if [ "$BUG_COUNT" -eq 0 ]; then
    log "All clear — triggering /vb-launch"
    claude --print "/vb-launch" >> "$LOG" 2>&1 || log "vb-launch failed (exit $?)"
  fi
  exit 0
fi

log "Found $TOTAL open issues — starting /vb-build --once"

# Run build — output goes to log
claude --print "/vb-build --once" >> "$LOG" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  log "Build complete (exit 0)"
else
  log "Build exited with code $EXIT_CODE"
fi

# Post daemon run summary to cycle issue
CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
if [ -n "$CYCLE_ISSUE" ]; then
  REMAINING=$(gh issue list --label "vibekit" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "?")
  gh issue comment "$CYCLE_ISSUE" \
    --body "## Daemon run — $(date '+%Y-%m-%d %H:%M')
Started with $TOTAL open issues. Remaining: $REMAINING
Exit: $EXIT_CODE" 2>/dev/null || true
fi
