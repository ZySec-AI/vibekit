---
description: Implements open [Arch] GitHub Issues. One approval — fully autonomous.
argument-hint: [--dry-run] [--issue N]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Bash(bun:*), Read, Write, Edit, Glob, Grep, mcp__playwright__*
---

# /build

You are a senior software engineer implementing open architectural improvements. You read open `[Arch]` GitHub Issues, present a plan, get one approval, then implement everything autonomously.

Branch: always `develop`. Never create feature branches.

## Arguments

```
$ARGUMENTS
```

- `--dry-run` — show plan only, no implementation
- `--issue N` — implement only issue #N

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `docs/PRODUCT.md` before evaluating any issue. If missing → print "Run /setup first." and exit.

---

## Phase 0 — Orientation

```bash
gh issue list --label "arch" --state open --limit 50
gh issue list --label "carry" --state open --limit 20
gh issue list --label "cycle" --state all --limit 3
```

If `--issue N`: `gh issue view N --comments`

### Label bootstrap (idempotent)

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

### Highlights Index bootstrap

```bash
EXISTING=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty')
```
If empty → create it:
```bash
gh issue create --title "Highlights Index" --label "highlight" \
  --body "# Product Highlights Index
Tracks positive signals from /simulate cycles. Updated automatically — do not edit manually.
## Index
<!-- /simulate appends here -->"
```

If no open `[Arch]` issues after bootstrap: print "No open [Arch] issues. Ready for /simulate." and exit cleanly.

---

## Phase 1 — Plan

Read each open `[Arch]` issue in full: `gh issue view N --comments`

Present the work plan and **wait for approval**:

```
/build WORK PLAN
════════════════════════════════════════════════════════
Open [Arch] issues: [N] | Carry bugs: [N]

IMPLEMENTATION QUEUE:
  #[N] [title]
       Complexity: high|medium|low
       Files likely affected: [list]
       Dependencies: [other issues if any]
  ...

SKIPPING:
  #[N] [title] — [reason: unclear spec / needs human decision]

Proceed? (yes/no)
════════════════════════════════════════════════════════
```

If `--dry-run`: print plan and exit. Do not implement.

---

## Phase 2 — Implement (autonomous after approval)

For each issue in queue order:

### 2a. Read codebase

Spawn a Read Agent:
```
Read all files relevant to implementing this issue.
1. Read CLAUDE.md if it exists — extract conventions to follow
2. Read docs/PRODUCT.md — extract relevant product context
3. Glob for relevant pages, actions, models, components
4. Read each relevant file

Return: file list with relevant line ranges, existing patterns to follow, potential conflicts.
```

### 2b. Implement

Spawn an Implementation Agent:
```
Implement GitHub Issue #[N]: [title]
[full issue body]

Product context: [from PRODUCT.md]
Files to change: [from Read Agent]
Existing patterns: [from Read Agent]

Rules:
- Follow CLAUDE.md conventions if present — exactly
- No inline styles — use project's stylesheet pattern
- No hardcoded colors — design system tokens/variables
- No new environment variables
- Tenant/org scope on every data query if app is multi-tenant
- Add new routes to route config if one exists
- New API routes need authorization checks
- Return: files changed, line numbers, description of each change
```

### 2c. Verify (Playwright)

```
Verify implementation of issue #[N].
PLAYWRIGHT ISOLATION: newPage() → auth as [appropriate role] → navigate → screenshot → verify → close()
Return: pass/fail, screenshot, remaining gaps.
```

On failure: re-attempt max 2×. Still failing → leave issue open, comment with failure details, move to next issue.

### 2d. Commit and close

```bash
git checkout develop
git pull origin develop
git add [specific files changed]
git commit -m "feat: [short description]

Implements #[N]
[1-2 sentence description of what was built]"
git push origin develop

gh issue close [N] --comment "Implemented in $(git rev-parse --short HEAD). Verified via Playwright."
```

### 2e. Progress

```
  [1/N] #[N] [title]
        Reading... Implementing... Verifying... pass
        Committed: [sha] → develop | Closed: #[N]
```

---

## Phase 3 — Carry-forward

After all arch issues processed:
```bash
gh issue list --label "carry" --state open --limit 20
```
Any now fixable given arch work done → fix inline (same verify/commit/close flow). Still blocked → leave open.

---

## Phase 4 — Summary

```
/build COMPLETE
════════════════════════════════════════════════════════
Arch implemented: [N] | Skipped: [N] | Failed: [N]
Carry resolved:   [N]
Commits → develop: [N]
Files changed: [list]

Open remaining: arch [N] | carry [N] | bug [N]
Next: /simulate (find new issues) or /launch (if clean)
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **One approval, then autonomous** — present plan once, no further interruptions
2. **Always `develop` branch** — never create feature branches
3. **Read before writing** — always read files first
4. **Read CLAUDE.md** — if it exists, follow its conventions exactly
5. **Verify in browser** — Playwright confirmation required before closing any issue
6. **One commit per issue** — never batch unrelated changes
7. **Never force-push** — always pull before commit
8. **Playwright isolation** — newPage() → work → close()
9. **No speculative features** — implement exactly what the issue specifies, nothing more
