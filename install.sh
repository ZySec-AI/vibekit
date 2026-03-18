#!/usr/bin/env bash
# vibekit installer — https://github.com/ZySec-AI/vibekit
# Usage: curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash
#
# Installs vibekit commands, hooks, daemon, and settings into the current project.
# Run this from your project root.

set -e

BASE="https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop"
GLOBAL=false

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=true ;;
  esac
done

echo ""
echo "vibekit installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$GLOBAL" = true ]; then
  PROJECT_ROOT="$HOME"
elif git rev-parse --show-toplevel &>/dev/null; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
else
  echo "No git repo detected — installing globally to ~/.claude/"
  PROJECT_ROOT="$HOME"
fi

COMMANDS_DIR="$PROJECT_ROOT/.claude/commands"
HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
VIBEKIT_DIR="$PROJECT_ROOT/.vibekit"
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

mkdir -p "$COMMANDS_DIR" "$HOOKS_DIR" "$VIBEKIT_DIR"

echo "Installing to: $PROJECT_ROOT"
echo ""

# Commands
echo "Commands:"
for cmd in vb-setup vb-simulate vb-build vb-launch vb-review vb-pitch vb-daemon; do
  printf "  %-20s" "/$cmd"
  if curl -fsSL "$BASE/.claude/commands/$cmd.md" -o "$COMMANDS_DIR/$cmd.md"; then
    echo "✓"
  else
    echo "FAILED"
    exit 1
  fi
done

echo ""
echo "Hooks:"

# session-start.sh
printf "  %-20s" "session-start.sh"
if curl -fsSL "$BASE/.claude/hooks/session-start.sh" -o "$HOOKS_DIR/session-start.sh"; then
  chmod +x "$HOOKS_DIR/session-start.sh"
  echo "✓"
else
  echo "FAILED"; exit 1
fi

# session-stop.sh
printf "  %-20s" "session-stop.sh"
if curl -fsSL "$BASE/.claude/hooks/session-stop.sh" -o "$HOOKS_DIR/session-stop.sh"; then
  chmod +x "$HOOKS_DIR/session-stop.sh"
  echo "✓"
else
  echo "FAILED"; exit 1
fi

echo ""
echo "Daemon:"

# daemon.sh
printf "  %-20s" "daemon.sh"
if curl -fsSL "$BASE/.vibekit/daemon.sh" -o "$VIBEKIT_DIR/daemon.sh"; then
  chmod +x "$VIBEKIT_DIR/daemon.sh"
  echo "✓"
else
  echo "FAILED"; exit 1
fi

echo ""
echo "Settings:"

# Merge hooks into settings.json (preserve existing content)
printf "  %-20s" "settings.json"
HOOK_CONFIG='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-start.sh",
            "timeout": 15,
            "statusMessage": "Loading project state..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-stop.sh",
            "timeout": 30,
            "statusMessage": "Saving session transcript..."
          }
        ]
      }
    ]
  }
}'

if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  # Merge: preserve existing keys, deep-merge hooks
  MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$HOOK_CONFIG") 2>/dev/null) && \
    echo "$MERGED" > "$SETTINGS" || echo "$HOOK_CONFIG" > "$SETTINGS"
elif [ ! -f "$SETTINGS" ]; then
  echo "$HOOK_CONFIG" > "$SETTINGS"
fi
echo "✓"

# Update .gitignore to exclude vibekit scratch files
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
  if ! grep -q "\.vibekit/" "$PROJECT_ROOT/.gitignore"; then
    printf "\n# vibekit scratch files\n.vibekit/*.jsonl\n.vibekit/*.txt\n.vibekit/*.log\n.vibekit/*.lock\n.vibekit/*.png\n.vibekit/*.mjs\n.vibekit/*.json\n" >> "$PROJECT_ROOT/.gitignore"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done. vibekit installed to: $PROJECT_ROOT"
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Commit to share with your team:"
echo "       git add .claude .vibekit && git commit -m \"chore: add vibekit\""
echo ""
echo "  2. Start your dev server, then run in Claude Code:"
echo ""
echo "  Quick start (zero questions):"
echo "       /vb-setup --auto && /vb-simulate"
echo ""
echo "  Guided start:"
echo "       /vb-setup        ← one prompt to describe your product"
echo "       /vb-simulate     ← find & fix issues"
echo ""
echo "  Autonomous loop (runs without Claude open):"
echo "       /vb-daemon install"
echo ""
echo "  Requires: gh CLI (brew install gh) + gh auth login"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
