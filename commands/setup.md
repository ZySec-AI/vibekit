---
description: Bootstrap a project for the /simulate → /build → /launch workflow. Run once per project.
argument-hint: (no arguments needed)
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Bash(brew:*), Bash(curl:*), Read, Write, Glob
---

# /setup

Bootstrap this project for the vibekit development loop. Run once when starting on a new project.

---

## Step 1 — Prerequisites check

```bash
claude --version    2>/dev/null || echo "MISSING: npm install -g @anthropic-ai/claude-code"
gh --version        2>/dev/null || echo "MISSING: brew install gh"
gh auth status      2>/dev/null || echo "NOT AUTHENTICATED: gh auth login"
git remote get-url origin 2>/dev/null || echo "NO REMOTE: git remote add origin <url>"
```

Detect package manager:
```bash
if   [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ];       then PM="yarn"
elif [ -f "bun.lockb" ];       then PM="bun"
elif [ -f "package.json" ];    then PM="npm"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then PM="pip/poetry"
elif [ -f "Gemfile" ];         then PM="bundle"
else PM="unknown"; fi
```

Print status table:
```
PREREQUISITE CHECK
══════════════════════════════════════
Claude Code:      [OK vX.X.X | MISSING]
gh CLI:           [OK vX.X.X | MISSING]
gh auth:          [OK (@user) | NOT AUTHENTICATED]
git remote:       [OK (url)   | MISSING]
Package manager:  [pnpm|yarn|bun|npm|pip|bundle|unknown]
══════════════════════════════════════
```

If any required prerequisite is missing: print install command and exit. Do not proceed.

---

## Step 2 — PRODUCT.md

```bash
test -f docs/PRODUCT.md && echo "exists" || echo "missing"
```

If missing, ask:
```
MISSING: docs/PRODUCT.md

This file drives all commands — personas, GTM artifacts, role-appropriate audits.
Create it now? (yes/no)
```

If yes: read the codebase first (CLAUDE.md, README.md, src/ or app/ structure), then ask 3 questions:
1. "What does this product do? (1–2 sentences)"
2. "Who are the primary users/buyers? List roles if multiple (e.g. Admin, Manager, Analyst)"
3. "What are the top 2–3 pain points it solves?"

Write `docs/PRODUCT.md` with these sections:
- **Product summary** (from Q1)
- **ICP** — who buys it, what industries/geographies apply
- **Roles** — every named user role with a 1-line description of what they do
- **Primary tasks per role** — the 2–3 most frequent actions per role (used by /simulate click-count gate)
- **Pain points** (from Q3)
- **Competitive context** — what it replaces or competes with (ask if unclear)
- **Current product state** — tech stack detected from codebase, dev server command, seed command if any

This file is the single source of truth for all vibekit commands. Keep it updated as the product evolves.

---

## Step 3 — GitHub labels (idempotent)

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

## Step 4 — Highlights Index issue

```bash
EXISTING=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty')
```

If empty:
```bash
gh issue create \
  --title "Highlights Index" \
  --label "highlight" \
  --body "# Product Highlights Index

Tracks all positive signals observed during /simulate cycles. Updated automatically — do not edit manually.

## Index
<!-- /simulate appends entries here -->
"
```

---

## Step 5 — Summary

```
/setup COMPLETE
════════════════════════════════════════════════════════
Project:        [repo name from git remote]
Branch:         develop
PRODUCT.md:     [created | already existed]
Labels:         12 confirmed
Highlights Index: #[N]

THE LOOP:
  /simulate   — find & fix issues → GitHub Issues
  /build      — implement [Arch] issues (one approval → autonomous)
  /launch     — release gates → GTM docs → GitHub release

START:
  1. make dev       (or your project's dev server command)
  2. /simulate
  3. Watch it go

Check issues anytime:
  gh issue list --label "bug"  --state open
  gh issue list --label "arch" --state open
════════════════════════════════════════════════════════
```
