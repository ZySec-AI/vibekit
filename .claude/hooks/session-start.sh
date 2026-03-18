#!/bin/bash
# vibekit session-start — dashboard + prompt capture
# Runs on every Claude Code session start (non-blocking)

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
VIBEKIT_DIR="$PROJECT_ROOT/.vibekit"

# Capture the initial user prompt from CLAUDE_SESSION_PROMPT env (set by Claude Code)
# Fallback: write a sentinel so session-stop knows to read from transcript
mkdir -p "$VIBEKIT_DIR"
SESSION_START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
echo "$SESSION_START_TIME" > "$VIBEKIT_DIR/session-start-time.txt"

if [ -n "${CLAUDE_SESSION_PROMPT:-}" ]; then
  echo "$CLAUDE_SESSION_PROMPT" > "$VIBEKIT_DIR/last-prompt.txt"
fi

# Dashboard — only if gh is available
if ! gh auth status &>/dev/null 2>&1; then
  echo "=== vibekit — $(basename "$PROJECT_ROOT") ==="
  echo "gh not authenticated — run: gh auth login"
  echo "======================================="
  exit 0
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"
REPO_NAME="$(basename "$PROJECT_ROOT")"

echo "=== vibekit — ${REPO_NAME} ==="
echo "Branch: $BRANCH"
echo ""

HIGHLIGHTS=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
if [ -z "$HIGHLIGHTS" ]; then
  echo "Project not initialised — run /vb-setup first."
  echo "======================================="
  exit 0
fi

BUG_COUNT=$(gh issue list --label "bug" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
CARRY_COUNT=$(gh issue list --label "carry" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")

echo "Open bugs: $BUG_COUNT  |  Arch: $ARCH_COUNT  |  Carry: $CARRY_COUNT"

gh issue list --label "bug,critical" --state open --limit 3 --json number,title \
  --jq '.[] | "  CRITICAL #\(.number) — \(.title)"' 2>/dev/null || true
gh issue list --label "bug,high" --state open --limit 3 --json number,title \
  --jq '.[] | "  HIGH     #\(.number) — \(.title)"' 2>/dev/null || true
echo ""

gh issue list --label "cycle" --state all --limit 1 --json title,createdAt \
  --jq '.[] | "Last cycle: \(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "Last cycle: none"

# Daemon status
PLIST="$HOME/Library/LaunchAgents/com.vibekit.$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-').daemon.plist"
if [ -f "$PLIST" ] && launchctl list 2>/dev/null | grep -q "com.vibekit"; then
  echo "Daemon: running (autonomous loop active)"
elif [ -f "$PLIST" ]; then
  echo "Daemon: installed but not running (run /vb-daemon start)"
fi

echo ""
if gh issue list --label "bug,critical" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null | grep -q .; then
  echo "NEXT: /vb-simulate — critical bugs open"
elif [ "$ARCH_COUNT" != "?" ] && [ "$ARCH_COUNT" -gt 0 ] 2>/dev/null; then
  echo "NEXT: /vb-build ($ARCH_COUNT arch issues) or /vb-simulate"
else
  echo "NEXT: /vb-simulate (continuous) or /vb-launch (ready to ship)"
fi
echo "======================================="
