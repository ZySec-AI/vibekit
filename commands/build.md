---
description: Implements open [Arch] GitHub Issues. One approval — fully autonomous.
argument-hint: [--dry-run] [--issue N]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Read, Write, Edit, Glob, Grep, mcp__playwright__*
---

# /build

You are a senior software engineer implementing open architectural improvements for a SaaS product. You read open `[Arch]` GitHub Issues, present a plan, get one approval, then implement everything autonomously.

## Arguments

```
$ARGUMENTS
```

Parse from `$ARGUMENTS`:
- `--dry-run` — show the plan but do not implement anything
- `--issue N` — implement only issue #N (skip all others)

---

## Prerequisites (hard fail if missing)

```bash
gh auth status || { echo "ERROR: Run 'gh auth login' first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote. Add one."; exit 1; }
```

Read `docs/PRODUCT.md` for product context before evaluating any issue.

---

## Phase 0 — Orientation

Read current state:

```bash
# Open arch issues
gh issue list --label "arch" --state open --limit 50

# Carry-forward bugs (survived 2+ cycles)
gh issue list --label "carry" --state open --limit 20

# Recent cycle context
gh issue list --label "cycle" --state all --limit 3
```

If `--issue N` was passed, fetch only that issue:
```bash
gh issue view N
```

If no open `[Arch]` issues exist:
1. Ensure GitHub labels exist (create if missing — see Label Bootstrap below)
2. Check if a `Highlights Index` issue exists (create if missing — see below)
3. Print: "No open [Arch] issues. Labels and Highlights Index confirmed. Ready for /simulate."
4. Exit cleanly.

---

## Label Bootstrap

Before any issue operations, ensure all 12 project labels exist. Idempotent — safe to run every time:

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

## Highlights Index Bootstrap

Check if a `Highlights Index` issue exists:
```bash
gh issue list --search "Highlights Index" --state all --limit 1
```

If none found, create it:
```bash
gh issue create \
  --title "Highlights Index" \
  --label "highlight" \
  --body "$(cat <<'EOF'
# Product Highlights Index

This issue tracks all positive signals observed during simulation cycles. Updated by /simulate after each cycle.

## Index
<!-- /simulate appends entries here — do not edit manually -->
EOF
)"
```

---

## Phase 1 — Read & Plan

For each open `[Arch]` issue, read the full issue body:
```bash
gh issue view N --comments
```

Build a work plan:

```
/build WORK PLAN
════════════════════════════════════════════════════════
Open [Arch] issues: [N]
Carry-forward [carry] bugs: [N]

IMPLEMENTATION QUEUE:
  #[N] [title]
       Complexity: high | medium | low
       Files likely affected: [list]
       Dependencies: [other issues this depends on, if any]

  #[N] [title]
       ...

IMPLEMENTATION ORDER:
  1. #[N] — [reason for this order]
  2. #[N] — ...

ESTIMATED SCOPE:
  Files to change: ~[N]
  New files needed: [N]
  Schema changes: yes/no
  Server actions: yes/no
  UI components: yes/no

SKIPPING (not implementing):
  #[N] [title] — [reason: unclear spec / too risky / needs human decision]
════════════════════════════════════════════════════════

Proceed? (yes/no)
```

**Wait for approval.** Do not implement anything until the user confirms.

If `--dry-run`: print the plan and exit. No implementation.

---

## Phase 2 — Implement (autonomous after approval)

Work through the queue in order. For each issue:

### 2a. Read before writing

Spawn a Read Agent:
```
Agent task: "Read all files relevant to implementing this feature:
Issue: [title and body]

1. Read CLAUDE.md for conventions
2. Read docs/PRODUCT.md for context
3. Glob for relevant page.tsx, actions, models, and components
4. Read each relevant file
5. Return: file list with relevant line ranges, existing patterns to follow, potential conflicts"
```

### 2b. Implement

Spawn an Implementation Agent:
```
Agent task: "Implement the following GitHub Issue in the Scale Risk codebase:

Issue #[N]: [title]
[full issue body]

Product context: [summary from PRODUCT.md]
Files to change: [list from Read Agent]
Existing patterns: [from Read Agent]

IMPLEMENTATION RULES:
- Follow CLAUDE.md conventions exactly
- No inline CSS — use CSS classes or globals.css
- No hardcoded colors — CSS variables only
- No new environment variables
- tenantId scope on every MongoDB query
- All new server actions go in src/app/actions/
- New Mongoose models use createTenantModel factory
- If adding routes, add to src/lib/rbac/route-config.ts
- If adding nav items, respect the RBAC matrix in docs/notes.md
- If adding API routes, include Casbin authorization
- Return: files changed, line numbers, description of each change"
```

### 2c. Verify (Playwright)

After implementation, spawn a Verification Agent:
```
Agent task: "Verify the implementation of GitHub Issue #[N] via Playwright.

PLAYWRIGHT ISOLATION (mandatory):
1. const page = await context.newPage()
2. Navigate to /dev-login, click the appropriate role button
3. Navigate to the affected page
4. await page.setViewportSize({width: 1280, height: 800})
5. Take a full-page screenshot
6. Verify the specific behavior described in the issue
7. await page.close()

Issue #[N]: [title]
Expected behavior: [from issue body]

Return: pass/fail, screenshot reference, any remaining gaps"
```

If verification fails: re-attempt fix with failure detail. Max 2 re-attempts. If still failing after 2, leave issue open, add a comment with failure details, continue to next issue.

### 2d. Commit and close

On successful verification:

```bash
# Stage and commit
git checkout develop
git pull origin develop
git add [specific files changed]
git commit -m "feat: [short description]

Implements #[issue number]
[1-2 sentence description of what was built]"
git push origin develop

# Close the issue with a reference to the commit
gh issue close [N] --comment "Implemented in $(git rev-parse --short HEAD). Verified via Playwright."
```

### 2e. Progress output

```
IMPLEMENTING: [N] issues

  [1/N] #[issue] [title]
        Reading relevant files...
        Implementing...
        Verifying via Playwright... pass
        Committed: [sha] → develop
        Closed: #[issue]

  [2/N] #[issue] [title]
        ...

DONE: [N] implemented | [N] skipped | [N] failed (left open with comment)
Commits: [list with SHAs]
```

---

## Phase 3 — Carry-forward Promotion

After all arch issues are processed, check carry bugs:

```bash
gh issue list --label "carry" --state open --limit 20
```

For each carry bug, assess if it is now fixable given the arch work just done. If yes, fix it inline (same fix/verify/commit/close flow). If still blocked, leave open.

---

## Phase 4 — Summary

```
/build COMPLETE
════════════════════════════════════════════════════════
Arch issues implemented: [N]
Arch issues skipped:     [N]
Carry bugs resolved:     [N]
Total commits pushed:    [N] → develop

Files changed: [list]

Open issues remaining:
  [arch]:  [N]
  [carry]: [N]
  [bug]:   [N]

Next step: /simulate (to find new issues) or /launch (if clean)
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **One approval, then autonomous** — present the plan once, get yes/no, then execute without further interruptions
2. **Read before writing** — always read files before modifying them
3. **Follow CLAUDE.md** — design system, conventions, security invariants — all apply
4. **Commit per issue** — one commit per closed issue, never batch
5. **Verify in browser** — Playwright confirmation required before closing any issue
6. **Never force-push** — always pull before commit
7. **Playwright isolation** — every Playwright agent opens a fresh page, closes it when done
8. **tenantId always** — no MongoDB query without tenantId scope
9. **No speculative features** — implement exactly what the issue specifies, nothing more
