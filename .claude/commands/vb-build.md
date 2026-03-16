---
description: Autonomous development loop — builds, simulates, watches for new issues, repeats until production-ready.
argument-hint: [--dry-run] [--issue N] [--once] [--interval N] [--max-rounds N]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Bash(npx:*), Bash(uv:*), Read, Write, Edit, Glob, Grep
---

# /vb-build

You are a senior software engineer running the full autonomous development loop. By default you:

1. Build all open `[Arch]` and `vibekit`-labeled issues
2. Run the test suite to catch regressions
3. Run a `/vb-simulate` cycle to find new issues
4. **Poll for new issues** (created manually on GitHub, labeled `vibekit`, or new `arch` issues)
5. Repeat until launch gates pass and no new issues arrive (max 20 rounds)

One approval at the start, then fully autonomous. Ctrl+C to stop.

Branch: always `develop`. Never create feature branches.

## Arguments

```
$ARGUMENTS
```

- *(no flags)* — **default: full autonomous loop with watch** — build → simulate → poll for new issues → repeat. Runs indefinitely.
- `--dry-run` — show plan only, no implementation
- `--issue N` — implement only issue #N, then exit (no simulate, no loop)
- `--once` — build all open arch issues once, then exit (no simulate cycle, no polling)
- `--interval N` — polling interval in minutes between loop iterations (default: 5)
- `--max-rounds N` — safety limit on autonomous rounds (default: 20). Stops after N rounds even if issues remain.

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

### Phase 0.5 — Mode selection

Parse flags from `$ARGUMENTS`:
```bash
MODE="default"
INTERVAL=5
MAX_ROUNDS=20
BUILT=0
SIM_CYCLES=0
TESTS_RUN=0
TESTS_FAILED=0

echo "$ARGUMENTS" | grep -q '\-\-once' && MODE="once"
echo "$ARGUMENTS" | grep -q '\-\-dry-run' && MODE="dryrun"
ISSUE_ARG=$(echo "$ARGUMENTS" | grep -oE '\-\-issue[[:space:]]+[0-9]+' | grep -oE '[0-9]+$')
[ -n "$ISSUE_ARG" ] && MODE="single"
INTERVAL_ARG=$(echo "$ARGUMENTS" | grep -oE '\-\-interval[[:space:]]+[0-9]+' | grep -oE '[0-9]+$')
[ -n "$INTERVAL_ARG" ] && INTERVAL="$INTERVAL_ARG"
MAX_ARG=$(echo "$ARGUMENTS" | grep -oE '\-\-max-rounds[[:space:]]+[0-9]+' | grep -oE '[0-9]+$')
[ -n "$MAX_ARG" ] && MAX_ROUNDS="$MAX_ARG"
```

### Detect test runner

```bash
TEST_CMD=""
if   grep -q '"vitest"' package.json 2>/dev/null; then TEST_CMD="pnpm exec vitest run"
elif grep -q '"jest"'   package.json 2>/dev/null; then TEST_CMD="pnpm exec jest"
elif grep -q '"test"'   package.json 2>/dev/null; then TEST_CMD="pnpm test"
elif test -f pyproject.toml && grep -q "pytest" pyproject.toml 2>/dev/null; then TEST_CMD="uv run pytest"
fi
```

**If default mode (no flags, or only `--interval`):**

This is the full autonomous loop — build, simulate, watch for new issues, repeat. One approval, then runs indefinitely until launch gates pass or Ctrl+C.

Print banner:
```
/vb-build
════════════════════════════════════════════════════════
Autonomous loop: build → test → simulate → watch → repeat
Poll interval:   [INTERVAL] minutes (for new issues)
Max rounds:      [MAX_ROUNDS]
Test runner:     [TEST_CMD or "none detected"]
Ctrl+C to stop
════════════════════════════════════════════════════════
```

**Get one approval before starting.** Show the current state:
```bash
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_COUNT=$(gh issue list --label "bug" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
VK_COUNT=$(gh issue list --label "vibekit" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
```

```
Current state:
  Open arch issues:       [ARCH_COUNT]
  Open bugs:              [BUG_COUNT]
  vibekit-labeled issues: [VK_COUNT]

This will autonomously:
  1. Build all open [Arch] + [vibekit]-labeled issues
  2. Run test suite after each build (catch regressions)
  3. Run a /vb-simulate cycle (Playwright journeys + UX audit)
  4. Poll GitHub every [INTERVAL]m for new issues (including ones you create on your phone)
  5. Build new issues as they arrive
  6. Repeat until launch gates pass and no new issues arrive (max [MAX_ROUNDS] rounds)

Proceed? (yes/no)
```

Wait for approval. Install signal trap:
```bash
trap 'rm -f .vibekit/build.lock; echo ""; echo "/vb-build stopped. Built: $BUILT issues | $SIM_CYCLES sim cycles | $TESTS_RUN test runs."; exit 0' INT TERM
```

After approval, enter the main loop:

```
AUTO_ROUND=0
PROCESSED=""

while [ $AUTO_ROUND -lt $MAX_ROUNDS ]; do
  AUTO_ROUND=$((AUTO_ROUND + 1))
  echo ""
  echo "═══════════════════════════════════════════"
  echo "ROUND $AUTO_ROUND / $MAX_ROUNDS"
  echo "═══════════════════════════════════════════"

  # ── Step 1 — Build all open arch + vibekit-labeled issues ──
  echo $$ > .vibekit/build.lock

  ARCH_ISSUES=$(gh issue list --label "arch" --state open --limit 50 --json number,title \
    --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || echo "")
  VK_ISSUES=$(gh issue list --label "vibekit" --state open --limit 50 --json number,title \
    --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || echo "")
  ALL_ISSUES=$(printf '%s\n%s\n' "$ARCH_ISSUES" "$VK_ISSUES" | sort -u | grep -v '^$' || echo "")

  # Filter already-processed — but only skip if issue is still closed
  # (re-opened issues get picked up again)
  BUILD_QUEUE=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    NUM=$(echo "$line" | awk '{print $1}')
    if echo "$PROCESSED" | grep -qw "$NUM"; then
      # Check if issue was re-opened — if so, allow re-processing
      STATE=$(gh issue view "$NUM" --json state --jq '.state' 2>/dev/null || echo "OPEN")
      [ "$STATE" = "OPEN" ] || continue
    fi
    BUILD_QUEUE="${BUILD_QUEUE}${line}\n"
  done <<< "$ALL_ISSUES"

  if [ -n "$BUILD_QUEUE" ]; then
    QUEUE_COUNT=$(printf '%b' "$BUILD_QUEUE" | grep -c . || echo "0")
    echo "Building $QUEUE_COUNT issues..."

    # Run Phase 2a–2d for each issue (read → implement → verify → commit/close)
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      NUM=$(echo "$line" | awk '{print $1}')
      echo "[$(date '+%H:%M')] Building issue #${NUM}..."

      # Phase 2a–2d for this issue (same logic as --issue N path in Phase 2 below)
      # After successful close:
      #   - If issue had "vibekit" label → remove it
      gh issue view "$NUM" --json labels --jq '.labels[].name' 2>/dev/null \
        | grep -q "^vibekit$" && gh issue edit "$NUM" --remove-label "vibekit" 2>/dev/null || true
      #   - Move to Done on project board
      ISSUE_URL=$(gh issue view "$NUM" --json url --jq '.url' 2>/dev/null || echo "")
      [ -n "$ISSUE_URL" ] && add_to_project "$ISSUE_URL" "Done"

      PROCESSED="$PROCESSED $NUM"
      BUILT=$((BUILT + 1))
    done <<< "$(printf '%b' "$BUILD_QUEUE")"
  else
    echo "No new issues to build."
  fi

  rm -f .vibekit/build.lock

  # ── Step 1b — Run test suite (catch regressions) ──
  if [ -n "$TEST_CMD" ]; then
    echo ""
    echo "Running tests..."
    TESTS_RUN=$((TESTS_RUN + 1))
    TEST_OUTPUT=$($TEST_CMD 2>&1) || {
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "TESTS FAILED — attempting fix..."
      # Read failing test output, identify the failure, fix the code or test
      # Max 2 fix attempts. If still failing after 2 attempts:
      #   - Create a [Bug] issue for the test failure
      #   - Continue to simulate step (do not block the loop)
      echo "$TEST_OUTPUT" | tail -20
    }
    [ $? -eq 0 ] && echo "Tests passed."
  fi

  # ── Step 2 — Run a /vb-simulate cycle ──
  # On odd rounds: full simulate (journeys + UX audit)
  # On even rounds: journey-only (faster feedback, skip full UX audit)
  echo ""
  SIM_CYCLES=$((SIM_CYCLES + 1))
  if [ $((AUTO_ROUND % 2)) -eq 1 ]; then
    echo "Running full simulation cycle (journeys + UX audit)..."
    SIM_MODE="full"
  else
    echo "Running quick simulation cycle (journeys only)..."
    SIM_MODE="journey-only"
  fi

  # Spawn a Simulate Agent to run the /vb-simulate workflow.
  # The agent executes the full Phase 0–7 pipeline from /vb-simulate:
  #   Phase 0: Preflight — detect server, login mechanism, cycle number
  #   Phase 1: Customer journeys — generate personas, Playwright journeys, triage, fix bugs inline
  #   Phase 2: UX audit (skip if SIM_MODE=journey-only) — 9 dimensions, 3 iterations
  #   Phase 3: Performance audit (skip if SIM_MODE=journey-only)
  #   Phase 4: Dedup
  #   Phase 5: GitHub output — [Sim] Cycle N parent issue, Highlights Index update
  #   Phase 6: GTM sync — update DEMO-SEQUENCE.md if highlights changed
  #   Phase 7: Status
  #
  # Agent prompt:
  #   "Run a /vb-simulate cycle. Mode: [full | journey-only].
  #    Server: http://localhost:[port]. Login: [DEV_LOGIN_PATH or detected].
  #    Read docs/PRODUCT.md for personas and roles.
  #    Follow the full /vb-simulate Phase 0–7 workflow.
  #    If mode is journey-only, skip Phase 2 (UX audit) and Phase 3 (performance).
  #    Fix all fixable bugs inline, commit to develop, create GitHub Issues.
  #    Return: bugs found, bugs fixed, arch issues created, cycle number."

  # ── Step 3 — Check launch gates ──
  NEW_ARCH=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "0")
  NEW_CRITICAL=$(gh issue list --label "bug,critical" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")
  NEW_HIGH=$(gh issue list --label "bug,high" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")
  NEW_VK=$(gh issue list --label "vibekit" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "0")

  echo ""
  echo "Round $AUTO_ROUND complete:"
  echo "  Open arch:     $NEW_ARCH"
  echo "  vibekit queue: $NEW_VK"
  echo "  Critical bugs: $NEW_CRITICAL"
  echo "  High bugs:     $NEW_HIGH"

  # Launch-ready: no open arch, no critical/high bugs, no vibekit queue
  if [ "$NEW_ARCH" -eq 0 ] && [ "$NEW_CRITICAL" -eq 0 ] && [ "$NEW_HIGH" -eq 0 ] && [ "$NEW_VK" -eq 0 ]; then
    echo ""
    echo "All clear — launch gates pass."
    echo ""
    echo "Watching for new issues every ${INTERVAL}m... (Ctrl+C to stop)"
  fi

  # ── Step 4 — Poll for new issues ──
  echo "[$(date '+%H:%M')] Next check in ${INTERVAL}m..."
  sleep $((INTERVAL * 60))

  # Fetch new issues — if none arrived and gates already pass, keep watching
  POLL_ARCH=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "0")
  POLL_VK=$(gh issue list --label "vibekit" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "0")
  POLL_CRIT=$(gh issue list --label "bug,critical" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")
  POLL_HIGH=$(gh issue list --label "bug,high" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "0")

  TOTAL_OPEN=$((POLL_ARCH + POLL_VK + POLL_CRIT + POLL_HIGH))

  if [ "$TOTAL_OPEN" -eq 0 ]; then
    echo "[$(date '+%H:%M')] Still clean — no new issues. Watching..."
    # Stay in loop — user may create an issue from their phone at any time
    continue
  fi

  echo "[$(date '+%H:%M')] New work detected — starting round $((AUTO_ROUND + 1))..."
  # Loop continues → builds new issues → simulates → polls again
done

# Max rounds reached
if [ $AUTO_ROUND -ge $MAX_ROUNDS ]; then
  echo ""
  echo "Reached max rounds ($MAX_ROUNDS). Stopping."
  echo "Remaining: arch $NEW_ARCH | vibekit $NEW_VK | critical $NEW_CRITICAL | high $NEW_HIGH"
  echo "Run /vb-build again to continue, or /vb-launch if ready."
fi
```

Print summary (on Ctrl+C via trap, or on max rounds):
```
/vb-build COMPLETE
════════════════════════════════════════════════════════
Rounds completed:  [AUTO_ROUND] / [MAX_ROUNDS]
Arch implemented:  [BUILT]
Sim cycles run:    [SIM_CYCLES]
Test runs:         [TESTS_RUN] ([TESTS_FAILED] failures)

Final state:
  Open arch:     [N]
  Critical bugs: [N]
  High bugs:     [N]

[If all clear: "Ready to ship — run /vb-launch"]
[If issues remain: "Run /vb-build to continue or fix manually"]
════════════════════════════════════════════════════════
```

**If `--once`:** proceed to Phase 1 below (build all arch issues once, no simulate cycle, no polling).

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
