---
description: Trend analysis across simulation cycles — bug velocity, severity trends, carry bugs, world-class scores.
argument-hint: [--cycle N] [--compare N..M] [--export]
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Read, Write, Glob
---

# /vibekit-metrics

You are a data analyst. Read GitHub Issues history to compute trends across simulation cycles and generate a metrics dashboard.

Read-only by default. Only writes `docs/METRICS.md` with `--export`.

## Arguments

```
$ARGUMENTS
```

- `--cycle N` — Show metrics for a specific cycle
- `--compare N..M` — Compare two cycles side by side
- `--export` — Write `docs/METRICS.md` (otherwise just prints to console)
- *(no flags)* — full history analysis, prints to console

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

---

## Phase 0 — Gather Data

### Fetch all cycle issues

```bash
gh issue list --label "cycle" --state all --limit 100 --json number,title,body,createdAt,closedAt \
  --jq '.[] | {number, title, body, createdAt, closedAt}'
```

Parse cycle numbers from titles: `[Sim] Cycle N — YYYY-MM-DD`

### Fetch all bug issues

```bash
gh issue list --label "bug" --state all --limit 200 --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'
```

### Fetch all arch issues

```bash
gh issue list --label "arch" --state all --limit 200 --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'
```

### Fetch carry bugs

```bash
gh issue list --label "carry" --state open --limit 50 --json number,title,createdAt,labels \
  --jq '.[] | {number, title, createdAt, labels: [.labels[].name]}'
```

### Fetch review issues

```bash
gh issue list --label "review" --state all --limit 200 --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'
```

If no cycle issues found:
```
No simulation cycles found. Run /vibekit-simulate first.
```
Exit.

---

## Phase 1 — Compute Metrics

### Bug velocity (per cycle)

For each cycle:
- Bugs found: count bug issues created between this cycle's date and the next cycle's date
- Bugs fixed: count bug issues closed in that same window
- Fix rate: fixed / found * 100

### Severity distribution (per cycle)

For each cycle, count bugs by severity label (critical, high, medium, low).

### Carry bug aging

For each open carry bug:
- Count how many cycles it has survived (cycles since createdAt)
- Sort by age (oldest first)

### World-class scores (per cycle)

Parse cycle issue bodies for world-class scores. Look for patterns like:
- `World-class: N/10`
- `Score: N/10`
- `Average: N/10`

If parseable: compute average per cycle.

### Fix rate

Per cycle: % of bugs fixed within the same cycle vs carried to next.

### Arch backlog

- Open arch issues over time (count at each cycle boundary)
- Trend: increasing, stable, or decreasing

### Time between cycles

Days between consecutive cycle issue creation dates.

### Review metrics (if review issues exist)

- Review findings by dimension (security, quality, ui)
- Fix rate for review issues
- Open review issues by severity

---

## Phase 2 — Output

### If `--cycle N`:

Show detailed metrics for cycle N only.

### If `--compare N..M`:

Side-by-side comparison of cycles N and M.

```
CYCLE COMPARISON — Cycle [N] vs Cycle [M]
════════════════════════════════════════════════════════
                      Cycle [N]       Cycle [M]
Bugs found:           [N]             [N]
Bugs fixed:           [N]             [N]
Fix rate:             [N]%            [N]%
Critical:             [N]             [N]
High:                 [N]             [N]
Medium:               [N]             [N]
Low:                  [N]             [N]
World-class avg:      [N]/10          [N]/10
Arch issues opened:   [N]             [N]
Arch issues closed:   [N]             [N]
════════════════════════════════════════════════════════
```

### Default (full history):

```
METRICS — [repo name]
════════════════════════════════════════════════════════
Cycles completed: [N]

BUG VELOCITY
  Cycle 1:  [bar]  [N] found, [N] fixed ([N]%)
  Cycle 2:  [bar]  [N] found, [N] fixed ([N]%)
  Cycle 3:  [bar]  [N] found, [N] fixed ([N]%)
  ...
  Trend: [improving | stable | worsening]

SEVERITY TREND
  Critical:  [N] → [N] → [N]    ([improving | stable | worsening])
  High:      [N] → [N] → [N]    ([improving | stable | worsening])
  Medium:    [N] → [N] → [N]    ([improving | stable | worsening])
  Low:       [N] → [N] → [N]    ([improving | stable | worsening])

CARRY BUGS: [N] open
  #[N] "[title]"  — [N] cycles (oldest)
  #[N] "[title]"  — [N] cycles
  ...

ARCH BACKLOG: [N] open (was [N] after cycle 1)
  Trend: [increasing | stable | decreasing]

[IF REVIEW ISSUES EXIST:]
REVIEW FINDINGS: [N] total ([N] open, [N] fixed)
  Security: [N] | Quality: [N] | UI: [N]

WORLD-CLASS SCORES (if available)
  Cycle 1: [N]/10
  Cycle 2: [N]/10
  ...
  Trend: [improving | stable | worsening]

CYCLE CADENCE
  Average: [N] days between cycles
  Last cycle: [N] days ago

RECOMMENDED:
  [Based on metrics:
   - Carry bugs > 0 → "Fix carry bugs → /vibekit-simulate"
   - Critical/high open → "Critical bugs open → /vibekit-simulate"
   - Arch backlog growing → "Arch backlog growing → /vibekit-build"
   - All trends improving → "Ready for /vibekit-launch"
   - No recent cycles → "No cycles in [N] days → /vibekit-simulate"]
════════════════════════════════════════════════════════
```

Use ASCII bar charts for bug velocity:
```
  Cycle 1:  ████████░░  12 found, 10 fixed (83%)
```
Each block = 10% of fix rate. Filled = fixed, empty = unfixed.

---

## Phase 3 — Export (--export only)

Write `docs/METRICS.md` with the same data plus Mermaid charts:

```markdown
# Metrics Dashboard — [repo name]

Generated by `/vibekit-metrics` on [date].

## Bug Velocity

\`\`\`mermaid
xychart-beta
  title "Bugs Found vs Fixed"
  x-axis ["Cycle 1", "Cycle 2", "Cycle 3"]
  y-axis "Count"
  bar [12, 8, 9]
  line [10, 8, 7]
\`\`\`

## Severity Trend

\`\`\`mermaid
xychart-beta
  title "Bug Severity Over Time"
  x-axis ["Cycle 1", "Cycle 2", "Cycle 3"]
  y-axis "Count"
  bar [2, 0, 0]
  bar [4, 2, 1]
  bar [3, 4, 3]
  bar [3, 2, 5]
\`\`\`

## Carry Bugs
[table of carry bugs with age]

## Arch Backlog
[trend description + count]

## Recommendations
[same as console output]
```

Commit:
```bash
git checkout develop && git pull origin develop
git add docs/METRICS.md
git commit -m "docs: update metrics dashboard

/vibekit-metrics --export
Cycles: [N] | Bugs: [found]/[fixed] | Carry: [N]"
git push origin develop
```

---

## Ground Rules

1. **Data-driven** — every metric comes from GitHub Issues, no guessing
2. **Read-only by default** — only writes with `--export`
3. **Honest trends** — report worsening metrics, don't sugarcoat
4. **Handle missing data** — if cycle bodies don't contain scores, skip that metric
5. **Idempotent export** — overwrites METRICS.md each run
6. **No invented data** — if there's only 1 cycle, don't show trends
7. **Actionable recommendations** — always end with a specific next command
