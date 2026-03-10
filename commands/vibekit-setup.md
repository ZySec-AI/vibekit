---
description: Bootstrap a project for the /vibekit-simulate → /vibekit-build → /vibekit-launch workflow. Run once per project.
argument-hint: [--auto] [--refresh]
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Bash(brew:*), Bash(curl:*), Bash(chmod:*), Read, Write, Edit, Glob, Grep
---

# /vibekit-setup

Bootstrap this project for the vibekit development loop. Run once when starting on a new project.

## Arguments

```
$ARGUMENTS
```

- `--auto` — generate PRODUCT.md entirely from codebase scan, zero questions. Marks uncertain sections with `[INFERRED]`.
- `--refresh` — re-scan codebase, diff against existing PRODUCT.md, propose updates for stale sections.

---

## Step 1 — Prerequisites check

```bash
claude --version    2>/dev/null || echo "MISSING: npm install -g @anthropic-ai/claude-code"
gh --version        2>/dev/null || echo "MISSING: https://cli.github.com — brew install gh (mac) / sudo apt install gh (linux)"
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

## Step 2 — PRODUCT.md (Detect-Draft-Confirm)

```bash
test -f docs/PRODUCT.md && echo "exists" || echo "missing"
```

### If `--refresh` flag and PRODUCT.md exists:
Read existing `docs/PRODUCT.md`. Run Phase A (codebase scan) below. Compare scan results against PRODUCT.md sections. For each section where the codebase has diverged (new routes, new roles, changed tech stack, new dependencies), show a diff:
```
PRODUCT.md REFRESH
══════════════════════════════════════════════════
Section: Current Product State
  - Tech stack: was "Next.js 13" → now "Next.js 14" (from package.json)
  - New routes found: /admin/audit-log, /settings/billing
  - New dependency: @stripe/stripe-js (suggests billing integration)

Section: User Roles
  - New role detected: "Billing Admin" (from routes + auth config)

Apply these updates? (yes / or tell me what to change)
══════════════════════════════════════════════════
```
Apply on approval. Max 2 revision rounds, then write and tell user to edit directly.
After PRODUCT.md refresh, skip to Step 3.

### If PRODUCT.md already exists (no --refresh):
Read it, print "PRODUCT.md already exists — skipping. Use --refresh to update." and continue to Step 2.25.

### If PRODUCT.md is missing (or --auto flag):

#### Phase A — Deep Codebase Scan (zero input)

Before asking anything, scan and extract from:
- `CLAUDE.md`, `README.md` — product description, features, audience
- `package.json` / `pyproject.toml` / `Gemfile` — name, description, dependencies (infer tech stack, auth lib, DB, UI framework)
- Route files (`routes.ts`, `App.tsx`, `urls.py`, etc.) — infer roles, pages, modules
- `.env.example` — service integrations
- Navigation components — menu items, role-based access
- DB schema / models — entities, relationships, multi-tenancy

Detect if this is a **greenfield project** (minimal code): fewer than 5 source files, no route files, no models/schema.

Print what was found:
```
CODEBASE SCAN
══════════════════════════════════════════════════
  Tech stack:     [e.g. Next.js 14 + TypeScript, Prisma + PostgreSQL]
  Auth:           [e.g. NextAuth (Google + credentials)]
  Dev server:     [e.g. pnpm dev (port 3000)]
  Seed command:   [e.g. pnpm seed]
  Routes found:   [e.g. /dashboard, /settings, /reports, /admin/users]
  Likely roles:   [e.g. Admin, User (from routes + auth config)]
  Modules:        [e.g. Dashboard, Reports, Settings, User Management]
══════════════════════════════════════════════════
```

If greenfield (almost nothing found), adjust the scan output:
```
CODEBASE SCAN
══════════════════════════════════════════════════
  This looks like a new project — not much code to scan yet.
  Tech stack:     [whatever detected, or "not yet determined"]
══════════════════════════════════════════════════
```

#### Phase B — Single Freeform Prompt (one interaction)

**If `--auto` flag:** skip Phase B entirely. Proceed to Phase C using only scan data.

**If greenfield project:**
```
This looks like a new project — not much code to scan yet.
Tell me: what are you building, who is it for, and what pain points does it solve?

(One paragraph is fine. Include roles if you know them already.)
```

**Otherwise (normal project with code):**
```
Tell me about your product — I'll combine this with what I found in the code:

  - What does it do and who is it for?
  - What pain points does it solve?
  - Who are the competitors?
  - Anything wrong in the scan above?

(One paragraph is fine. Skip anything I already got right.)
```

Wait for answer.

#### Phase C — Draft & Confirm (one interaction)

Generate complete `docs/PRODUCT.md` combining scan results + user input (or scan-only for `--auto`).

For `--auto` mode: mark any section that required guessing with `[INFERRED]` — e.g. `[INFERRED] Industries: B2B SaaS (based on tech stack and dependencies)`.

```markdown
# PRODUCT.md — [Product Name]

## Product Summary
[1–2 sentence description]

## Ideal Customer Profile (ICP)
- **Buyer**: [inferred from code + user input]
- **End users**: [all named roles]
- **Industries**: [from user input or inferred]
- **Company profile**: [infer from context — size, compliance requirements, etc.]

## User Roles
| Role | Tier | What they do |
|------|------|-------------|
[One row per role. Infer tier (Leadership/Manager/Operator/Admin) from role names and codebase.]

## Primary Tasks per Role
[For each role: list 3–5 most frequent actions they perform in the product.
Infer from codebase route structure + user answers. This drives /vibekit-simulate click-count gates.]

## Pain Points Solved
[Bullet list, customer-voice language]

## Key Differentiators
[Bullet list. Skip section if unknown.]

## Competitive Context
| Competitor / Alternative | How we win |
|--------------------------|-----------|
[Skip section if unknown.]

## Current Product State
- **Status**: [from user input or inferred]
- **Tech stack**: [detected from codebase — framework, DB, language]
- **Dev server**: [detected — e.g. `pnpm dev`, `npm run dev`, `python manage.py runserver`]
- **Seed command**: [detected if seed script exists — e.g. `pnpm seed`]
- **Auth**: [detected — e.g. NextAuth, Devise, Django auth, Supabase]

## Demo Sequences
[Generate 2–3 recommended demo flows for the buyer persona.
Each flow: 4–6 steps showing the product's highest-value moments.]
```

Show the draft, then ask:
```
Approve this? (yes / or tell me what to change)
```

Write on approval. Max 2 revision rounds, then write and tell user to edit directly.

Print: "PRODUCT.md written to docs/PRODUCT.md — review and edit any time. All vibekit commands re-read it on every run."

This file is the single source of truth for all vibekit commands. Keep it updated as the product evolves.

---

## Step 2.25 — CLAUDE.md generation

```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
```

**If CLAUDE.md already exists:** skip this step.

**If missing:** generate one from codebase analysis:

Scan:
- Project directory layout (auto-detect with `ls` and glob)
- Coding conventions (indentation, naming, import style — infer from 3-5 code samples)
- Tech stack specifics (framework, ORM, auth, with version numbers from lockfiles)
- Common commands (dev, seed, test, lint — from package.json scripts or equivalent)

Generate `CLAUDE.md`:

```markdown
# CLAUDE.md

## Project Structure
[auto-detected directory layout — top-level dirs with one-line purpose each]

## Tech Stack
[framework, ORM, auth, UI library — with version numbers from lockfiles]

## Common Commands
[dev, seed, test, lint — from package.json scripts or equivalent]

## Coding Conventions
[indentation, naming style, import conventions — inferred from code samples]

## Notes
- This project uses vibekit. See docs/PRODUCT.md for product context.
```

Show draft, ask:
```
CLAUDE.md generated. Approve? (yes / no / or tell me what to change)
```

Write on approval. Skip if user declines.

---

## Step 2.5 — Session hook auto-install

Create `.claude/hooks/session-start.sh`:

```bash
mkdir -p .claude/hooks
```

Write `.claude/hooks/session-start.sh`:
```bash
#!/bin/bash
BRANCH="$(git branch --show-current 2>/dev/null)"
echo "=== vibekit — $(basename $(git rev-parse --show-toplevel)) ==="
echo "Branch: $BRANCH"
echo ""
if ! gh auth status &>/dev/null; then
  echo "gh not authenticated — run: gh auth login"
  echo "Then run /vibekit-setup to initialise this project."
  exit 0
fi
HIGHLIGHTS=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
if [ -z "$HIGHLIGHTS" ]; then
  echo "Project not initialised — run /vibekit-setup first."
  exit 0
fi
BUG_COUNT=$(gh issue list --label "bug" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
CARRY_COUNT=$(gh issue list --label "carry" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
echo "Open bugs: $BUG_COUNT  |  Arch: $ARCH_COUNT  |  Carry: $CARRY_COUNT"
gh issue list --label "bug,critical" --state open --limit 3 --json number,title \
  --jq '.[] | "  CRITICAL #\(.number) — \(.title)"' 2>/dev/null
gh issue list --label "bug,high" --state open --limit 3 --json number,title \
  --jq '.[] | "  HIGH     #\(.number) — \(.title)"' 2>/dev/null
echo ""
gh issue list --label "cycle" --state all --limit 1 --json title,createdAt \
  --jq '.[] | "Last cycle: \(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "Last cycle: none"
echo ""
if gh issue list --label "bug,critical" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null | grep -q .; then
  echo "NEXT: /vibekit-simulate — critical bugs open"
elif [ "$ARCH_COUNT" -gt "0" ] 2>/dev/null; then
  echo "NEXT: /vibekit-build ($ARCH_COUNT arch issues) or /vibekit-simulate (next cycle)"
else
  echo "NEXT: /vibekit-simulate (continuous) or /vibekit-launch (ready to ship)"
fi
echo "======================================="
```

```bash
chmod +x .claude/hooks/session-start.sh
```

Then merge hook config into `.claude/settings.json`:
- If file doesn't exist: create it with the hook config
- If file exists: read it, merge the `SessionStart` hook into the `hooks` object (preserve any existing hooks)

Hook config to merge:
```json
{
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
    ]
  }
}
```

Print: `Session hook: installed (shows issue state on Claude Code start)`

---

## Step 3 — GitHub labels (idempotent)

```bash
gh label create "sim"       --color "0075ca" --description "From a simulation cycle"            2>/dev/null || true
gh label create "bug"       --color "d73a4a" --description "Fixable code issue"                 2>/dev/null || true
gh label create "arch"      --color "e4e669" --description "Needs /vibekit-build to implement"  2>/dev/null || true
gh label create "carry"     --color "ff6b35" --description "Bug surviving 2+ cycles unfixed"    2>/dev/null || true
gh label create "highlight" --color "0e8a16" --description "Positive signal for GTM artifacts"  2>/dev/null || true
gh label create "cycle"     --color "5319e7" --description "Parent issue per simulation cycle"  2>/dev/null || true
gh label create "wontfix"   --color "ffffff" --description "Triaged out"                        2>/dev/null || true
gh label create "v1.0"      --color "1d76db" --description "Launch milestone"                   2>/dev/null || true
gh label create "critical"  --color "b60205" --description "Severity: critical"                 2>/dev/null || true
gh label create "high"      --color "e11d48" --description "Severity: high"                     2>/dev/null || true
gh label create "medium"    --color "f97316" --description "Severity: medium"                   2>/dev/null || true
gh label create "low"       --color "84cc16" --description "Severity: low"                      2>/dev/null || true
gh label create "review"    --color "6f42c1" --description "From a /vibekit-review audit"        2>/dev/null || true
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

Tracks all positive signals observed during /vibekit-simulate cycles. Updated automatically — do not edit manually.

## Index
<!-- /vibekit-simulate appends entries here -->
"
```

---

## Step 5 — Summary

```
/vibekit-setup COMPLETE
════════════════════════════════════════════════════════
Project:        [repo name from git remote]
Branch:         develop
PRODUCT.md:     [created | already existed | refreshed]
CLAUDE.md:      [created | already existed | skipped]
Session hook:   installed
Labels:         13 confirmed
Highlights Index: #[N]

THE LOOP:
  /vibekit-simulate   — find & fix issues → GitHub Issues
  /vibekit-build      — implement [Arch] issues (one approval → autonomous)
  /vibekit-pitch      — generate all customer & developer docs
  /vibekit-launch     — release gates → GitHub release → merge to main

MORE:
  /vibekit-review     — deep code review (security, quality, UI)
  /vibekit-test       — generate & maintain test suites
  /vibekit-metrics    — trend analysis across cycles
  /vibekit-status     — project state at a glance

START:
  1. make dev       (or your project's dev server command)
  2. /vibekit-simulate
  3. Watch it go
════════════════════════════════════════════════════════
```
