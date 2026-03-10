---
description: Bootstrap a project for the /simulate → /build → /launch workflow. Run once per project.
argument-hint: (no arguments needed)
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Bash(brew:*), Read, Write
---

# /setup

Bootstrap this project for the 3-command development loop. Run this once when starting on a new project or repo.

---

## Step 1 — Check prerequisites

```bash
# Claude Code
claude --version 2>/dev/null || echo "MISSING: Install Claude Code → npm install -g @anthropic-ai/claude-code"

# GitHub CLI
gh --version 2>/dev/null || echo "MISSING: Install gh → brew install gh"

# gh auth
gh auth status 2>/dev/null || echo "NOT AUTHENTICATED: Run → gh auth login"

# git remote
git remote get-url origin 2>/dev/null || echo "NO REMOTE: Add one → git remote add origin <url>"

# pnpm (if this is a Node project)
pnpm --version 2>/dev/null || echo "OPTIONAL: Install pnpm → npm install -g pnpm"
```

Print a clean status table:
```
PREREQUISITE CHECK
══════════════════════════════════════
Claude Code:   [OK vX.X.X | MISSING]
gh CLI:        [OK vX.X.X | MISSING]
gh auth:       [OK (user: @name) | NOT AUTHENTICATED]
git remote:    [OK (url) | MISSING]
pnpm:          [OK vX.X.X | not required]
══════════════════════════════════════
```

If any required prerequisite is missing, print the install command and exit. Do not proceed.

---

## Step 2 — Check for PRODUCT.md

```bash
test -f docs/PRODUCT.md && echo "exists" || echo "missing"
```

If missing, print:
```
MISSING: docs/PRODUCT.md

This file tells /simulate and /launch about your product's ICP, roles, and competitive context.
It makes customer personas realistic and GTM artifacts accurate.

Create it now? (yes/no)
```

If yes: generate a starter `docs/PRODUCT.md` by reading the codebase:
- Read `CLAUDE.md` or `README.md` for product description
- Glob `src/` to understand the tech stack and module structure
- Ask the user 3 questions:
  1. "What does this product do? (1-2 sentences)"
  2. "Who is the primary buyer? (role title + industry)"
  3. "What are the top 2-3 pain points it solves?"
- Write `docs/PRODUCT.md` using the template structure from the Scale Risk example, adapted to this project

---

## Step 3 — Create GitHub labels (idempotent)

```bash
gh label create "sim"       --color "0075ca" --description "From a simulation cycle"            2>/dev/null || true
gh label create "bug"       --color "d73a4a" --description "Fixable code issue"                 2>/dev/null || true
gh label create "arch"      --color "e4e669" --description "Needs /build to implement"          2>/dev/null || true
gh label create "carry"     --color "ff6b35" --description "Bug surviving 2+ cycles unfixed"    2>/dev/null || true
gh label create "highlight" --color "0e8a16" --description "Positive signal for GTM artifacts"  2>/dev/null || true
gh label create "cycle"     --color "5319e7" --description "Parent issue per simulation cycle"  2>/dev/null || true
gh label create "wontfix"   --color "ffffff" --description "Triaged out"                        2>/dev/null || true
gh label create "v1.0"      --color "1d76db" --description "Launch milestone"                   2>/dev/null || true
gh label create "critical"  --color "b60205" --description "Severity: critical"                 2>/dev/null || true
gh label create "high"      --color "e11d48" --description "Severity: high"                     2>/dev/null || true
gh label create "medium"    --color "f97316" --description "Severity: medium"                   2>/dev/null || true
gh label create "low"       --color "84cc16" --description "Severity: low"                      2>/dev/null || true
```

---

## Step 4 — Create Highlights Index issue

```bash
# Only create if it doesn't exist
EXISTING=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty')
```

If empty:
```bash
gh issue create \
  --title "Highlights Index" \
  --label "highlight" \
  --body "$(cat <<'EOF'
# Product Highlights Index

Tracks all positive signals observed during /simulate cycles. Updated automatically — do not edit manually.

## Index
<!-- /simulate appends entries here -->
EOF
)"
```

---

## Step 5 — Summary

```
/setup COMPLETE
════════════════════════════════════════════════════════
Project:        [repo name from git remote]
Branch:         [current branch]
PRODUCT.md:     [created | already existed]
GitHub labels:  12 created/confirmed
Highlights Index issue: #[N] (or already existed)

YOU ARE READY. The 3-command loop:

  /simulate          — find & fix issues, output GitHub Issues
  /build             — implement open [Arch] issues (one approval → autonomous)
  /launch --dry-run  — check release gates + generate GTM docs

QUICK START:
  1. Start your dev server (e.g. pnpm dev)
  2. Run /simulate
  3. Watch it go

Check issue state anytime:
  gh issue list --label "bug" --state open
  gh issue list --label "arch" --state open
════════════════════════════════════════════════════════
```
