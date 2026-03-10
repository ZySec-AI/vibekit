#!/usr/bin/env bash
# vibekit installer — https://github.com/ZySec-AI/vibekit
# Usage: curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash
#
# Installs all 9 vibekit commands into .claude/commands/ in the current directory.
# Run this from your project root.

set -e

BASE="https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/commands"
GLOBAL=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=true ;;
  esac
done

echo ""
echo "vibekit installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$GLOBAL" = true ]; then
  DEST="$HOME/.claude/commands"
elif git rev-parse --show-toplevel &>/dev/null; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  DEST="$PROJECT_ROOT/.claude/commands"
else
  # Not in a git repo — fall back to global install
  echo "No git repo detected — installing globally to ~/.claude/commands"
  echo "(To install into a specific project, cd into it first.)"
  echo ""
  DEST="$HOME/.claude/commands"
fi

mkdir -p "$DEST"

echo "Installing to: $DEST"
echo ""

for cmd in vibekit-setup vibekit-simulate vibekit-build vibekit-launch vibekit-status vibekit-pitch vibekit-review vibekit-test vibekit-metrics; do
  printf "  %-20s" "/$cmd"
  if curl -fsSL "$BASE/$cmd.md" -o "$DEST/$cmd.md"; then
    echo "✓"
  else
    echo "FAILED"
    echo "ERROR: Could not download $cmd.md — check your internet connection."
    exit 1
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done. 9 commands installed to: $DEST"
echo ""
echo "NEXT STEPS:"
if [ "$DEST" != "$HOME/.claude/commands" ]; then
  echo "  1. Commit to share with your team:"
  echo "       git add .claude/commands && git commit -m \"chore: add vibekit commands\""
  echo ""
  echo "  2. Start your dev server, then run in Claude Code:"
else
  echo "  Start your dev server, then run in Claude Code:"
fi
echo ""
echo "  Quick start (zero questions):"
echo "       /vibekit-setup --auto && /vibekit-simulate"
echo ""
echo "  Guided start:"
echo "       /vibekit-setup        ← one prompt to describe your product"
echo "       /vibekit-simulate     ← find & fix issues"
echo ""
echo "  Requires: gh CLI (brew install gh) + gh auth login"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
