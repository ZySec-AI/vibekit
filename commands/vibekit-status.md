---
description: Show project state at a glance — issues, gates, recommended next command.
argument-hint: (no arguments needed)
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Read, Glob
---

# /vibekit-status

Lightweight, read-only command showing project state at a glance.

---

## Step 1 — Gather state

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `docs/PRODUCT.md` presence. Read `CLAUDE.md` presence.

```bash
BRANCH="$(git branch --show-current)"
REPO="$(basename $(git rev-parse --show-toplevel))"

# PRODUCT.md
test -f docs/PRODUCT.md && PRODUCT="present" || PRODUCT="missing"

# CLAUDE.md
test -f CLAUDE.md && CLAUDE_MD="present" || CLAUDE_MD="missing"

# Issue counts
BUG_TOTAL=$(gh issue list --label "bug" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "?")
BUG_CRITICAL=$(gh issue list --label "bug,critical" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_HIGH=$(gh issue list --label "bug,high" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_MEDIUM=$(gh issue list --label "bug,medium" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_LOW=$(gh issue list --label "bug,low" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
CARRY_COUNT=$(gh issue list --label "carry" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")

# Last cycle
LAST_CYCLE=$(gh issue list --label "cycle" --state all --limit 1 --json title,createdAt --jq '.[0] | "\(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "none")

# Branch clean
DIRTY=$(git status --short 2>/dev/null | head -1)

# Highlights
test -f docs/HIGHLIGHTS.md && HIGHLIGHTS="present" || HIGHLIGHTS="missing"
```

---

## Step 2 — Compute gates

- **Gate 1** (no critical/high): PASS if `BUG_CRITICAL` = 0 and `BUG_HIGH` = 0, else FAIL
- **Gate 2** (carry bugs): PASS if `CARRY_COUNT` = 0, else WARNING
- **Gate 3** (branch clean): PASS if no uncommitted changes, else FAIL
- **Gate 4** (highlights): PASS if `docs/HIGHLIGHTS.md` exists and is non-empty, else WARNING

---

## Step 3 — Print status

```
PROJECT STATUS — [REPO]
══════════════════════════════════════════════════
Branch:          [BRANCH]
PRODUCT.md:      [present | missing]
CLAUDE.md:       [present | missing]
Last cycle:      [LAST_CYCLE]

ISSUES
  Open bugs:       [BUG_TOTAL] (critical: [N], high: [N], medium: [N], low: [N])
  Open arch:       [ARCH_COUNT]
  Carry bugs:      [CARRY_COUNT]

LAUNCH READINESS
  Gate 1 (no critical/high): [PASS | FAIL — N blocking]
  Gate 2 (carry bugs):       [PASS | WARNING — N open]
  Gate 3 (branch clean):     [PASS | FAIL — uncommitted changes]
  Gate 4 (highlights):       [PASS | WARNING — missing]

RECOMMENDED NEXT
  [Based on state:
   - PRODUCT.md missing → "/vibekit-setup — project not initialised"
   - critical/high bugs → "/vibekit-simulate — N blocking bugs need fixing"
   - arch issues open → "/vibekit-build — N arch issues to implement"
   - all gates pass → "/vibekit-launch — ready to ship"
   - else → "/vibekit-simulate — next cycle"]
══════════════════════════════════════════════════
```
