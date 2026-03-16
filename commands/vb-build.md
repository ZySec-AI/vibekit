---
description: Full autonomous loop — build arch issues, simulate, repeat until launch-ready. One approval, then hands-off.
argument-hint: [--dry-run] [--issue N] [--once] [--daemon] [--interval N]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Bash(npx:*), Bash(uv:*), Read, Write, Edit, Glob, Grep
---

# /vb-build

You are a senior software engineer running the full autonomous development loop. By default: build all open `[Arch]` issues, run a `/vb-simulate` cycle to find new issues, build again, repeat — until launch gates pass or no new issues emerge. One approval at the start, then fully autonomous.

Branch: always `develop`. Never create feature branches.

## Arguments

```
$ARGUMENTS
```

- *(no flags)* — **default: full autonomous loop** — build → simulate → build → repeat until launch gates pass
- `--dry-run` — show plan only, no implementation
- `--issue N` — implement only issue #N (no simulate, no loop)
- `--once` — build all open arch issues once, then stop (no simulate cycle, no loop)
- `--daemon` — watch mode: poll for new `arch` and `vibekit`-labeled issues, implement automatically
- `--interval N` — polling interval in minutes when in daemon mode (default: 5)

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `docs/PRODUCT.md` before evaluating any issue. If missing → print "Run /vb-setup first." and exit.

Load dev login path for Playwright verification:
```bash
DEV_LOGIN_PATH=""
[ -f ".vibekit/repo.env" ] && DEV_LOGIN_PATH=$(grep "DEV_LOGIN_PATH" .vibekit/repo.env 2>/dev/null | cut -d= -f2)
```

---

## Phase 0 — Orientation

### Load project board config

```bash
PROJECT_CONFIGURED=false
[ -f ".vibekit/project.env" ] && source .vibekit/project.env || true
```

Define `add_to_project()` helper — moves closed issues to Done on the Kanban board:
```bash
add_to_project() {
  local URL="$1" STATUS="$2"
  [ "$PROJECT_CONFIGURED" = "true" ] || return
  [ -n "$PROJECT_ID" ] || return
  ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" --owner "@me" --url "$URL" --format json --jq '.id' 2>/dev/null || echo "")
  [ -n "$ITEM_ID" ] || return
  OPT_VAR="STATUS_OPT_$(echo "$STATUS" | sed 's/ /_/g' | tr '[:lower:]' '[:upper:]')"
  OPT_ID="${!OPT_VAR}"
  [ -n "$OPT_ID" ] || return
  gh project item-edit --id "$ITEM_ID" --field-id "$STATUS_FIELD_ID" \
    --project-id "$PROJECT_ID" --single-select-option-id "$OPT_ID" 2>/dev/null || true
}
```

### Phase 0.5 — Daemon check

Parse flags from `$ARGUMENTS`:
```bash
DAEMON_MODE=false
INTERVAL=5
BUILT=0
PROCESSED=""

echo "$ARGUMENTS" | grep -q '\-\-daemon' && DAEMON_MODE=true
INTERVAL_ARG=$(echo "$ARGUMENTS" | grep -oE '\-\-interval[[:space:]]+[0-9]+' | grep -oE '[0-9]+$')
[ -n "$INTERVAL_ARG" ] && INTERVAL="$INTERVAL_ARG"
```

**If `--daemon` mode:**

Print banner:
```
/vb-build DAEMON MODE
════════════════════════════════════════════════════════
Watching for: [arch] and [vibekit]-labeled issues
Poll interval: [N] minutes
Lock file:     .vibekit/build.lock
Ctrl+C to stop
════════════════════════════════════════════════════════
```

Install signal trap:
```bash
trap 'rm -f .vibekit/build.lock; echo ""; echo "Daemon stopped. Built: $BUILT issues."; exit 0' INT TERM
```

Enter poll loop:
```bash
while true; do
  # Stale lock cleanup — remove if PID no longer running or is this process
  if [ -f ".vibekit/build.lock" ]; then
    LOCK_PID=$(cat .vibekit/build.lock 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ]; then
      kill -0 "$LOCK_PID" 2>/dev/null && [ "$LOCK_PID" != "$$" ] || rm -f .vibekit/build.lock
    fi
  fi

  # Skip if another build is running
  if [ -f ".vibekit/build.lock" ]; then
    sleep $((INTERVAL * 60))
    continue
  fi

  # Fetch open arch + vibekit-labeled issues, deduplicate
  ARCH=$(gh issue list --label "arch" --state open --limit 50 --json number,title \
    --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || echo "")
  TRIGGER=$(gh issue list --label "vibekit" --state open --limit 50 --json number,title \
    --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || echo "")
  ALL=$(printf '%s\n%s\n' "$ARCH" "$TRIGGER" | sort -u | grep -v '^$' || echo "")

  # Filter issues already processed this session
  NEW=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    NUM=$(echo "$line" | awk '{print $1}')
    echo "$PROCESSED" | grep -qw "$NUM" || NEW="${NEW}${line}\n"
  done <<< "$ALL"

  if [ -z "$NEW" ]; then
    echo "[$(date '+%H:%M')] Watching... next check in ${INTERVAL}m"
    sleep $((INTERVAL * 60))
    continue
  fi

  # Process each new issue using the standard Phase 2 flow
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    NUM=$(echo "$line" | awk '{print $1}')
    echo $$ > .vibekit/build.lock

    echo "[$(date '+%H:%M')] Building issue #${NUM}..."

    # Run Phase 2a–2d for this issue (read → implement → verify → commit/close)
    # (Same logic as --issue N path below)
    # After successful close:
    #   - If issue had "vibekit" label → remove it
    gh issue view "$NUM" --json labels --jq '.labels[].name' 2>/dev/null \
      | grep -q "^vibekit$" && gh issue edit "$NUM" --remove-label "vibekit" 2>/dev/null || true
    #   - Move to Done on project board
    ISSUE_URL=$(gh issue view "$NUM" --json url --jq '.url' 2>/dev/null || echo "")
    [ -n "$ISSUE_URL" ] && add_to_project "$ISSUE_URL" "Done"

    PROCESSED="$PROCESSED $NUM"
    BUILT=$((BUILT + 1))
    rm -f .vibekit/build.lock
  done <<< "$(printf '%b' "$NEW")"

  sleep $((INTERVAL * 60))
done
```

**If default mode (no `--once`, `--issue`, `--daemon`, or `--dry-run`):**

Full autonomous loop — build all arch issues, then simulate, then build again, repeat until launch-ready. This is the default behavior.

Print banner:
```
/vb-build
════════════════════════════════════════════════════════
Full autonomous loop: build → simulate → build → repeat
Stops when: launch gates pass OR no new issues after a cycle
Ctrl+C to stop
════════════════════════════════════════════════════════
```

**Get one approval before starting.** Show the current state:
```bash
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_COUNT=$(gh issue list --label "bug" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
```

```
Current state:
  Open arch issues: [ARCH_COUNT]
  Open bugs:        [BUG_COUNT]

This will autonomously:
  1. Implement all open [Arch] issues
  2. Run a /vb-simulate cycle (Playwright journeys + UX audit)
  3. Implement any new [Arch] issues that emerged
  4. Repeat until launch gates pass or no new issues found

Proceed? (yes/no)
```

Wait for approval. After approval, enter the auto loop:

```
AUTO_ROUND=0
MAX_ROUNDS=10

while [ $AUTO_ROUND -lt $MAX_ROUNDS ]; do
  AUTO_ROUND=$((AUTO_ROUND + 1))
  echo ""
  echo "═══════════════════════════════════════════"
  echo "AUTO ROUND $AUTO_ROUND"
  echo "═══════════════════════════════════════════"

  # Step 1 — Build all open arch issues
  ARCH_ISSUES=$(gh issue list --label "arch" --state open --limit 50 --json number,title \
    --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || echo "")

  if [ -n "$ARCH_ISSUES" ]; then
    echo "Building $(echo "$ARCH_ISSUES" | wc -l | tr -d ' ') arch issues..."
    # Run Phase 2a–2d for each open arch issue (same logic as standard build)
    # For each: read → implement → verify via Playwright → commit → close → move to Done
  else
    echo "No open arch issues."
  fi

  # Step 2 — Run a /vb-simulate cycle
  echo "Running simulation cycle..."
  # Execute the full /vb-simulate workflow inline:
  #   - Generate personas from PRODUCT.md
  #   - Run Playwright journeys (sequential)
  #   - Fix all fixable bugs inline → commit to develop
  #   - Create [Bug] issues (closed with SHA) and [Arch] issues (left open)
  #   - Run 9-dimension UX audit across all pages
  #   - Run Core Web Vitals scan
  #   - Create [Sim] Cycle N parent issue
  #   - Update Highlights Index issue
  # Use the same Phase 1–6 logic from /vb-simulate

  # Step 3 — Check if we should continue
  NEW_ARCH=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "0")
  NEW_CRITICAL=$(gh issue list --label "bug,critical" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")
  NEW_HIGH=$(gh issue list --label "bug,high" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")

  echo ""
  echo "Round $AUTO_ROUND complete:"
  echo "  Open arch:     $NEW_ARCH"
  echo "  Critical bugs: $NEW_CRITICAL"
  echo "  High bugs:     $NEW_HIGH"

  # Exit conditions
  if [ "$NEW_ARCH" -eq 0 ] && [ "$NEW_CRITICAL" -eq 0 ] && [ "$NEW_HIGH" -eq 0 ]; then
    echo ""
    echo "All clear — no open arch issues, no critical/high bugs."
    echo "Launch gates likely pass. Run /vb-launch to ship."
    break
  fi

  if [ "$NEW_ARCH" -eq 0 ] && ([ "$NEW_CRITICAL" -gt 0 ] || [ "$NEW_HIGH" -gt 0 ]); then
    echo ""
    echo "No arch issues but critical/high bugs remain."
    echo "These should be fixable — running another simulate cycle..."
    # Continue loop — simulate will fix inline bugs
  fi

  # Safety: if this round produced no new arch issues AND no bugs were fixed,
  # we're likely stuck
  # (The loop tracks issue counts between rounds to detect no-progress)
done

if [ $AUTO_ROUND -ge $MAX_ROUNDS ]; then
  echo ""
  echo "Reached max rounds ($MAX_ROUNDS). Stopping."
  echo "Remaining: arch $NEW_ARCH | critical $NEW_CRITICAL | high $NEW_HIGH"
fi
```

Print auto mode summary:
```
/vb-build COMPLETE
════════════════════════════════════════════════════════
Rounds completed:  [AUTO_ROUND]
Arch implemented:  [total across all rounds]
Bugs fixed inline: [total across all rounds]
Sim cycles run:    [total]

Final state:
  Open arch:     [N]
  Critical bugs: [N]
  High bugs:     [N]

[If all clear: "Ready to ship — run /vb-launch"]
[If issues remain: "Run /vb-simulate or fix manually"]
════════════════════════════════════════════════════════
```

Exit after the loop completes.

**If `--once`:** proceed to Phase 1 below (build all arch issues once, no simulate cycle).

```bash
gh issue list --label "arch" --state open --limit 50
gh issue list --label "carry" --state open --limit 20
gh issue list --label "cycle" --state all --limit 3
```

If `--issue N`: `gh issue view N --comments`

### Label check

```bash
gh label list --limit 1 --json name --jq '.[0].name' 2>/dev/null | grep -q "sim" || {
  echo "Labels not found — run /vb-setup first."; exit 1;
}
```

### Highlights Index bootstrap

```bash
EXISTING=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty')
```
If empty → create it:
```bash
gh issue create --title "Highlights Index" --label "highlight" \
  --body "# Product Highlights Index
Tracks positive signals from /vb-simulate cycles. Updated automatically — do not edit manually.
## Index
<!-- /vb-simulate appends here -->"
```

If no open `[Arch]` issues after bootstrap: print "No open [Arch] issues. Ready for /vb-simulate." and exit cleanly.

---

## Phase 1 — Plan

Read each open `[Arch]` issue in full: `gh issue view N --comments`

Present the work plan and **wait for approval**:

```
/vb-build WORK PLAN
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

### 2c. Verify (npx playwright)

Write `.vibekit/_pw_verify_[N].mjs`:

```js
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();
// Auth as [appropriate role]
// Navigate to the affected route(s)
// Screenshot: await page.screenshot({ path: '.vibekit/_pw_verify_[N].png' })
// Assert the feature/fix is visible and functional
const result = { pass: true, notes: '', gaps: [] };
await browser.close();
console.log(JSON.stringify(result));
```

```bash
node .vibekit/_pw_verify_[N].mjs > .vibekit/_pw_verify_[N].json
rm -f .vibekit/_pw_verify_[N].mjs .vibekit/_pw_verify_[N].json .vibekit/_pw_verify_[N].png
```

Read the JSON. If `pass: false`: re-attempt fix max 2x. Still failing → leave issue open, comment with failure details, move to next issue.

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

# Move closed issue to Done on project board
ISSUE_URL=$(gh issue view [N] --json url --jq '.url' 2>/dev/null || echo "")
[ -n "$ISSUE_URL" ] && add_to_project "$ISSUE_URL" "Done"

# Cross-reference: comment on the open cycle issue so progress is visible there
CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
[ -n "$CYCLE_ISSUE" ] && gh issue comment "$CYCLE_ISSUE" \
  --body "Resolved #[N] — $(git rev-parse --short HEAD)" 2>/dev/null || true
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
/vb-build --once COMPLETE
════════════════════════════════════════════════════════
Arch implemented: [N] | Skipped: [N] | Failed: [N]
Carry resolved:   [N]
Commits → develop: [N]
Files changed: [list]

Open remaining: arch [N] | carry [N] | bug [N]
Next: /vb-build (full loop) or /vb-simulate or /vb-launch (if clean)
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **One approval, then autonomous** — present plan once, no further interruptions
2. **Always `develop` branch** — never create feature branches
3. **Read before writing** — always read files first
4. **Read CLAUDE.md** — if it exists, follow its conventions exactly
5. **Verify in browser** — `npx playwright` script confirmation required before closing any issue
6. **One commit per issue** — never batch unrelated changes
7. **Never force-push** — always pull before commit
8. **npx playwright only** — write `.vibekit/_pw_verify_N.mjs`, run with node, delete temp files after reading
9. **No speculative features** — implement exactly what the issue specifies, nothing more
