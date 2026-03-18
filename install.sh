#!/usr/bin/env bash
# vibekit installer — https://github.com/ZySec-AI/vibekit
# Usage: curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash
#
# Installs vibekit globally into ~/.claude/ — works across all projects.
# Run from anywhere. No git repo required.

set -e

BASE="https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop"

COMMANDS_DIR="$HOME/.claude/commands"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
# daemon lives in a fixed global location
DAEMON_DIR="$HOME/.vibekit"

mkdir -p "$COMMANDS_DIR" "$HOOKS_DIR" "$DAEMON_DIR"

echo ""
echo "vibekit installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installing globally to: ~/.claude/"
echo ""

# Commands
echo "Commands:"
for cmd in vb-setup vb-simulate vb-build vb-launch vb-review vb-pitch vb-daemon; do
  printf "  %-20s" "/$cmd"
  if curl -fsSL "$BASE/.claude/commands/$cmd.md" -o "$COMMANDS_DIR/$cmd.md" 2>/dev/null; then
    echo "✓"
  else
    echo "FAILED"; exit 1
  fi
done

echo ""
echo "Hooks:"

# session-start.sh — uses absolute path to itself, detects project at runtime
printf "  %-20s" "session-start.sh"
curl -fsSL "$BASE/.claude/hooks/session-start.sh" -o "$HOOKS_DIR/session-start.sh" 2>/dev/null
chmod +x "$HOOKS_DIR/session-start.sh"
echo "✓"

# session-stop.sh
printf "  %-20s" "session-stop.sh"
curl -fsSL "$BASE/.claude/hooks/session-stop.sh" -o "$HOOKS_DIR/session-stop.sh" 2>/dev/null
chmod +x "$HOOKS_DIR/session-stop.sh"
echo "✓"

echo ""
echo "Daemon:"
printf "  %-20s" "daemon.sh"
curl -fsSL "$BASE/.vibekit/daemon.sh" -o "$DAEMON_DIR/daemon.sh" 2>/dev/null
chmod +x "$DAEMON_DIR/daemon.sh"
echo "✓"

echo ""
echo "Settings:"

# Hook config using absolute paths — safe for global install
VIBEKIT_HOOKS='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/session-start.sh",
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
            "command": "bash ~/.claude/hooks/session-stop.sh",
            "timeout": 30,
            "statusMessage": "Saving session transcript..."
          }
        ]
      }
    ]
  }
}'

printf "  %-20s" "settings.json"
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  # Deep merge — existing keys win except hooks which we merge at array level
  MERGED=$(jq -s '
    .[0] as $existing |
    .[1] as $new |
    $existing * {
      "hooks": (
        ($existing.hooks // {}) * ($new.hooks // {}) |
        to_entries | map(
          .key as $k |
          {key: $k, value: (
            ($existing.hooks[$k] // []) + ($new.hooks[$k] // []) | unique_by(.hooks[0].command)
          )}
        ) | from_entries
      )
    }
  ' "$SETTINGS" <(echo "$VIBEKIT_HOOKS") 2>/dev/null)
  if [ -n "$MERGED" ]; then
    echo "$MERGED" > "$SETTINGS"
  else
    # jq merge failed — back up and write fresh hooks block
    cp "$SETTINGS" "${SETTINGS}.bak"
    echo "$VIBEKIT_HOOKS" > /tmp/vibekit-hooks.json
    echo "  (backed up existing settings to settings.json.bak)"
  fi
else
  echo "$VIBEKIT_HOOKS" > "$SETTINGS"
fi
echo "✓"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done. vibekit installed globally."
echo ""
echo "NEXT STEPS — run from any project directory:"
echo ""
echo "  Quick start (zero questions):"
echo "       /vb-setup --auto && /vb-simulate"
echo ""
echo "  Guided start:"
echo "       /vb-setup        ← describe your product once"
echo "       /vb-simulate     ← find & fix issues"
echo ""
echo "  Autonomous loop (no Claude session needed):"
echo "       /vb-daemon install"
echo ""
echo "  Requires: gh CLI (brew install gh) + gh auth login"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
