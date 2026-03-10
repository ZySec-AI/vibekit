#!/usr/bin/env bash
# vibekit installer — https://github.com/ZySec-AI/vibekit
# Usage: curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/develop/install.sh | bash
#
# Installs /setup /simulate /build /launch into .claude/commands/ in the current directory.
# Run this from your project root.

set -e

BASE="https://raw.githubusercontent.com/ZySec-AI/vibekit/develop/commands"
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
else
  # Detect project root (must have git)
  if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "ERROR: Not inside a git repository."
    echo "Run this from your project root (where .git lives)."
    echo "Or install globally: curl -fsSL ... | bash -s -- --global"
    exit 1
  fi
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  DEST="$PROJECT_ROOT/.claude/commands"
fi

mkdir -p "$DEST"

echo "Installing to: $DEST"
echo ""

for cmd in setup simulate build launch; do
  printf "  %-12s" "/$cmd"
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
echo "Done. 4 commands installed to: $DEST"
echo ""
echo "NEXT STEPS:"
if [ "$GLOBAL" = false ]; then
  echo "  1. Commit to share with your team:"
  echo "       git add .claude/commands && git commit -m \"chore: add vibekit commands\""
  echo ""
  echo "  2. Start your dev server, then run in Claude Code:"
else
  echo "  Start your dev server, then run in Claude Code:"
fi
echo "       /setup     ← run once to initialise GitHub labels + PRODUCT.md"
echo "       /simulate  ← find & fix issues"
echo "       /build     ← implement arch issues"
echo "       /launch    ← release"
echo ""
echo "  Requires: gh CLI (brew install gh) + gh auth login"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
