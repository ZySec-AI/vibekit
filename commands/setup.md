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

**If it already exists:** read it, print "PRODUCT.md already exists — skipping interview." and continue to Step 3.

**If missing:** first scan the codebase silently to gather context (read CLAUDE.md, README.md, package.json, and skim src/ or app/ route structure). Then run the interview below — ask each question one at a time and wait for the user's answer before asking the next.

```
MISSING: docs/PRODUCT.md

I'll ask you 8 questions to generate it. Answer as briefly or fully as you like.
Press Enter after each answer.

─────────────────────────────────────────────────────────
Q1 — What does this product do?
     (1–2 sentences. Plain language, no jargon.)
```

Wait for answer.

```
Q2 — Who are the primary buyers or decision-makers?
     (Job title + industry. e.g. "CISO at a mid-market bank",
      "Head of Engineering at a SaaS startup".)
```

Wait for answer.

```
Q3 — Who are the end users? List every named role if there are multiple.
     (e.g. "Admin, Manager, Analyst, Read-only Viewer"
      or "just the buyer themselves".)
```

Wait for answer.

```
Q4 — What are the top 2–3 pain points this product solves?
     (What was broken/manual/expensive before this existed?)
```

Wait for answer.

```
Q5 — What industries or verticals does this target?
     (e.g. "Financial services, healthcare, any regulated industry"
      or "B2B SaaS, any industry".)
```

Wait for answer.

```
Q6 — Who are the main competitors or alternatives?
     (Tools, spreadsheets, or workflows this replaces.
      Skip if none / too early to say.)
```

Wait for answer.

```
Q7 — What are 2–3 things this product does that competitors don't?
     (Key differentiators. Skip if unsure.)
```

Wait for answer.

```
Q8 — What is the current product state?
     (e.g. "MVP in private beta", "launched, 20 customers",
      "pre-launch, internal testing only".)
─────────────────────────────────────────────────────────
```

Wait for answer.

After all 8 answers, combine with codebase context already scanned and write `docs/PRODUCT.md` with these sections:

```markdown
# PRODUCT.md — [Product Name]

## Product Summary
[1–2 sentence description from Q1]

## Ideal Customer Profile (ICP)
- **Buyer**: [from Q2]
- **End users**: [from Q3 — all named roles]
- **Industries**: [from Q5]
- **Company profile**: [infer from Q2+Q5 — size, compliance requirements, etc.]

## User Roles
| Role | Tier | What they do |
|------|------|-------------|
[One row per role from Q3. Infer tier (Leadership/Manager/Operator/Admin) from role names and codebase.]

## Primary Tasks per Role
[For each role: list 3–5 most frequent actions they perform in the product.
Infer from codebase route structure + Q3 answers. This drives /simulate click-count gates.]

## Pain Points Solved
[From Q4 — bullet list, customer-voice language]

## Key Differentiators
[From Q7 — bullet list. Skip section if user skipped Q7.]

## Competitive Context
| Competitor / Alternative | How we win |
|--------------------------|-----------|
[From Q6. Skip section if user skipped Q6.]

## Current Product State
- **Status**: [from Q8]
- **Tech stack**: [detected from codebase — framework, DB, language]
- **Dev server**: [detected — e.g. `pnpm dev`, `npm run dev`, `python manage.py runserver`]
- **Seed command**: [detected if seed script exists — e.g. `pnpm seed`]
- **Auth**: [detected — e.g. NextAuth, Devise, Django auth, Supabase]

## Demo Sequences
[Generate 2–3 recommended demo flows for the buyer persona from Q2.
Each flow: 4–6 steps showing the product's highest-value moments.]
```

Print: "PRODUCT.md written to docs/PRODUCT.md — review and edit any time. All vibekit commands re-read it on every run."

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
