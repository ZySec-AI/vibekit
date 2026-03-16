---
description: Project status, metrics, and all customer/developer artifacts from PRODUCT.md + codebase.
argument-hint: [--status] [--metrics] [--sales] [--dev] [--investor] [--one-pager]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Read, Write, Edit, Glob, Grep
---

# /vb-pitch

You are a senior product marketer, developer advocate, sales enablement lead, and data analyst. Generate project status, trend metrics, and all documentation artifacts.

Branch: always `develop`.

## Arguments

```
$ARGUMENTS
```

- `--status` — Project state at a glance: issues, gates, recommended next command (read-only)
- `--metrics` — Trend analysis across simulation cycles: bug velocity, severity, carry bugs
- `--metrics --export` — Write `docs/METRICS.md` with Mermaid charts
- `--sales` — GTM-focused: sales play, product brochure, demo sequence
- `--dev` — Developer docs: API reference, architecture diagram (Mermaid), onboarding guide
- `--investor` — Pitch deck as markdown slides
- `--one-pager` — Single-page product overview
- *(no flags)* — generates all doc artifacts (sales + dev + investor + one-pager + product docs)

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

---

## If `--status`: Project Status (read-only)

Gather state:

```bash
BRANCH="$(git branch --show-current)"
REPO="$(basename $(git rev-parse --show-toplevel))"
test -f docs/PRODUCT.md  && PRODUCT="present"  || PRODUCT="missing"
test -f CLAUDE.md        && CLAUDE_MD="present" || CLAUDE_MD="missing"

BUG_TOTAL=$(gh issue list --label "bug" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "?")
BUG_CRITICAL=$(gh issue list --label "bug,critical" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_HIGH=$(gh issue list --label "bug,high" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_MEDIUM=$(gh issue list --label "bug,medium" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
BUG_LOW=$(gh issue list --label "bug,low" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
CARRY_COUNT=$(gh issue list --label "carry" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
LAST_CYCLE=$(gh issue list --label "cycle" --state all --limit 1 --json title,createdAt \
  --jq '.[0] | "\(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "none")
DIRTY=$(git status --short 2>/dev/null | head -1)
```

Compute gates:
- **Gate 1** (no critical/high): PASS if BUG_CRITICAL = 0 and BUG_HIGH = 0, else FAIL
- **Gate 2** (carry bugs): PASS if CARRY_COUNT = 0, else WARNING
- **Gate 3** (branch clean): PASS if no uncommitted changes, else FAIL
- **Gate 4** (highlights): PASS if Highlights Index issue has comments (i.e. at least one simulation cycle has run), else WARNING

Print:
```
PROJECT STATUS — [REPO]
══════════════════════════════════════════════════
Branch:          [BRANCH]
PRODUCT.md:      [present | missing]
CLAUDE.md:       [present | missing]
Last cycle:      [LAST_CYCLE]

ISSUES
  Open bugs:     [BUG_TOTAL] (critical: [N], high: [N], medium: [N], low: [N])
  Open arch:     [ARCH_COUNT]
  Carry bugs:    [CARRY_COUNT]

LAUNCH READINESS
  Gate 1 (no critical/high): [PASS | FAIL — N blocking]
  Gate 2 (carry bugs):       [PASS | WARNING — N open]
  Gate 3 (branch clean):     [PASS | FAIL — uncommitted changes]
  Gate 4 (highlights):       [PASS | WARNING — missing]

RECOMMENDED NEXT
  [Based on state:
   - PRODUCT.md missing       → "/vb-setup — project not initialised"
   - critical/high bugs open  → "/vb-simulate — N blocking bugs need fixing"
   - arch issues open         → "/vb-build — N arch issues to implement"
   - all gates pass           → "/vb-launch — ready to ship"
   - else                     → "/vb-simulate — next cycle"]
══════════════════════════════════════════════════
```

Exit after printing. Do not proceed to doc generation.

---

## If `--metrics`: Trend Analysis

### Phase 0 — Gather Data

```bash
gh issue list --label "cycle" --state all --limit 100 \
  --json number,title,body,createdAt,closedAt \
  --jq '.[] | {number, title, body, createdAt, closedAt}'

gh issue list --label "bug" --state all --limit 200 \
  --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'

gh issue list --label "arch" --state all --limit 200 \
  --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'

gh issue list --label "carry" --state open --limit 50 \
  --json number,title,createdAt,labels \
  --jq '.[] | {number, title, createdAt, labels: [.labels[].name]}'

gh issue list --label "review" --state all --limit 200 \
  --json number,title,labels,state,createdAt,closedAt \
  --jq '.[] | {number, title, labels: [.labels[].name], state, createdAt, closedAt}'
```

If no cycle issues found: print "No simulation cycles found. Run /vb-simulate first." and exit.

### Phase 1 — Compute Metrics

- **Bug velocity** — per cycle: found, fixed, fix rate %
- **Severity distribution** — critical/high/medium/low per cycle
- **Carry bug aging** — how many cycles each open carry bug has survived
- **World-class scores** — parse cycle bodies for `Score: N/10` patterns
- **Arch backlog** — open arch issues at each cycle boundary (trend: increasing/stable/decreasing)
- **Cycle cadence** — days between consecutive cycles
- **Review metrics** — if review issues exist: by dimension, fix rate, open by severity

### Phase 2 — Print

```
METRICS — [repo name]
════════════════════════════════════════════════════════
Cycles completed: [N]

BUG VELOCITY
  Cycle 1:  ████████░░  [N] found, [N] fixed ([N]%)
  Cycle 2:  ████████░░  [N] found, [N] fixed ([N]%)
  Trend: [improving | stable | worsening]

SEVERITY TREND
  Critical:  [N] → [N] → [N]   ([improving | stable | worsening])
  High:      [N] → [N] → [N]   ([improving | stable | worsening])

CARRY BUGS: [N] open
  #[N] "[title]" — [N] cycles (oldest)

ARCH BACKLOG: [N] open
  Trend: [increasing | stable | decreasing]

[IF REVIEW ISSUES EXIST:]
REVIEW FINDINGS: [N] total ([N] open, [N] fixed)
  Security: [N] | Quality: [N] | UI: [N]

WORLD-CLASS SCORES (if parseable)
  Cycle 1: [N]/10  →  Cycle [N]: [N]/10

CYCLE CADENCE
  Average: [N] days between cycles
  Last cycle: [N] days ago

RECOMMENDED:
  [carry bugs > 0        → "Fix carry bugs → /vb-simulate"
   critical/high open    → "/vb-simulate — critical bugs open"
   arch backlog growing  → "/vb-build"
   all trends improving  → "/vb-launch — ready to ship"
   no recent cycles      → "/vb-simulate — [N] days since last cycle"]
════════════════════════════════════════════════════════
```

Use ASCII bar charts: each block = 10% of fix rate. Filled = fixed, empty = unfixed.

### Phase 3 — Export (--metrics --export only)

Write `docs/METRICS.md` with Mermaid charts:

```markdown
# Metrics Dashboard — [repo name]

Generated by `/vb-pitch --metrics` on [date].

## Bug Velocity

\`\`\`mermaid
xychart-beta
  title "Bugs Found vs Fixed"
  x-axis ["Cycle 1", "Cycle 2", ...]
  y-axis "Count"
  bar [found counts]
  line [fixed counts]
\`\`\`

## Severity Trend
[mermaid xychart-beta for critical/high/medium/low over cycles]

## Carry Bugs
[table: issue number, title, cycles surviving]

## Arch Backlog
[trend description + open count]

## Recommendations
[same as console output]
```

Commit:
```bash
git checkout develop && git pull origin develop
git add docs/METRICS.md
git commit -m "docs: update metrics dashboard

/vb-pitch --metrics --export
Cycles: [N] | Bugs: [found]/[fixed] | Carry: [N]"
git push origin develop
```

Exit after printing/exporting. Do not proceed to doc generation.

---

## DOC GENERATION WORKFLOW (--sales / --dev / --investor / --one-pager / no flags)

### Prerequisites

```bash
test -f docs/PRODUCT.md || { echo "ERROR: docs/PRODUCT.md missing — run /vb-setup first."; exit 1; }
```

Read `docs/PRODUCT.md` before generating any artifact.

Fetch highlights data from the Highlights Index GitHub Issue (single source of truth — no local file):
```bash
HIGHLIGHTS_ISSUE=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
if [ -n "$HIGHLIGHTS_ISSUE" ]; then
  HIGHLIGHTS_DATA=$(gh issue view "$HIGHLIGHTS_ISSUE" --comments --json body,comments \
    --jq '[.body, (.comments[].body)] | join("\n---\n")' 2>/dev/null || echo "")
fi
```

If no Highlights Index issue exists or it has no comments: warn (not blocking). Artifacts that reference highlights will note "No simulation data yet — run /vb-simulate."

### Phase 0 — Codebase Scan

Scan to supplement PRODUCT.md and highlights data:
- Route files — all page routes, API endpoints, handler functions
- Models/schema — entities, relationships, data model
- Auth configuration — roles, permissions, middleware
- Package dependencies — key libraries, frameworks, integrations

### Phase 1 — Determine Scope

| Flag | Artifacts |
|------|-----------|
| `--sales` | SALES-PLAY.md, PRODUCT-BROCHURE.md, DEMO-SEQUENCE.md |
| `--dev` | API-REFERENCE.md, ARCHITECTURE.md, ONBOARDING.md |
| `--investor` | PITCH-DECK.md |
| `--one-pager` | ONE-PAGER.md |
| *(no flags)* | All of the above + PRODUCT-DOCS.md |

Print:
```
/vb-pitch — GENERATING
════════════════════════════════════════════════════════
Scope:     [all | sales | dev | investor | one-pager]
Artifacts: [N] files
Sources:   PRODUCT.md [present] | Highlights Index [N comments | no data]
════════════════════════════════════════════════════════
```

### Phase 2 — Generate Artifacts

Generate each artifact in scope. Overwrite if file exists. Every claim must be traceable to PRODUCT.md, Highlights Index issue, or codebase scan.

#### docs/SALES-PLAY.md (--sales or no flags)

Battlecard for account executives and sales engineers.

Sections:
- **ICP Snapshot** — who we sell to (from PRODUCT.md), 3 bullets
- **Opening Lines** — one killer opener per vertical in PRODUCT.md
- **Discovery Questions** — 5-7 high-value questions based on pain points
- **Value Props by Role** — 3 bullets per major role, grounded in Highlights Index issue
- **Objection Handling** — from simulation persona objections (Highlights Index issue)
- **Competitive Positioning** — how we win vs. competitors in PRODUCT.md (factual only)
- **Demo Sequence** — from Highlights Index issue, ordered by what resonated
- **Proof Points** — specific wow moments from Highlights Index issue (persona voice)
- **Known Gaps** — honest list of open arch issues and carry bugs

```bash
gh issue list --label "arch" --state open --limit 20 --json number,title --jq '.[] | "- #\(.number) \(.title)"'
gh issue list --label "carry" --state open --limit 20 --json number,title --jq '.[] | "- #\(.number) \(.title)"'
```

#### docs/PRODUCT-BROCHURE.md (--sales or no flags)

Customer-facing capability overview. Benefit-led, no jargon.

Sections:
- **The Problem** — 1 paragraph in customer language, from Highlights Index issue persona feedback
- **Who It's For** — role tier descriptions, what each gets from the product
- **Core Capabilities** — 4-6 capability groups with 3-5 benefit bullets each
- **How Customers Get Started** — onboarding overview, no professional services required

#### docs/DEMO-SEQUENCE.md (--sales or no flags)

Recommended demo flows per buyer vertical.
- One demo flow per vertical/buyer type from PRODUCT.md
- Each flow: 4-6 steps showing the product's highest-value moments
- Order steps by what resonated most in Highlights Index issue

#### docs/API-REFERENCE.md (--dev or no flags)

API reference from codebase scan.

Sections:
- **Base URL & Authentication**
- **Endpoints** — method, path, description, request/response shape per detected route
- **Error Handling** — common error codes and formats
- **Rate Limits** — if detectable from middleware
- **Webhooks / Events** — if applicable

#### docs/ARCHITECTURE.md (--dev or no flags)

Sections:
- **System Overview** — high-level Mermaid diagram, major components and data flow
- **Tech Stack** — framework, database, auth, hosting
- **Directory Structure** — annotated tree of key directories
- **Data Model** — Mermaid ER diagram from detected models/schema
- **Auth & Authorization** — how roles/permissions work
- **Key Patterns** — design patterns observed in codebase

#### docs/ONBOARDING.md (--dev or no flags)

Developer onboarding guide.

Sections:
- **Prerequisites** — tools needed
- **Setup** — clone, install, env, seed, run (reference `make dev` and `make seed`)
- **Project Structure** — where to find things
- **Common Tasks** — add a page, add an API route, add a model, run tests
- **Conventions** — from CLAUDE.md if present, else inferred
- **Useful Commands** — `make dev`, `make run`, `make seed`, `make clean`, test, lint

#### docs/PITCH-DECK.md (--investor or no flags)

Pitch deck as markdown slides (one `---` separator per slide).

Slides:
1. **Title** — product name, one-line description
2. **Problem** — what's broken today (from PRODUCT.md pain points)
3. **Solution** — what we do (from PRODUCT.md summary)
4. **How It Works** — 3-step visual flow
5. **Market** — ICP and market context
6. **Traction** — simulation cycle data if available (from Highlights Index issue)
7. **Product** — key capabilities (reference pages from codebase)
8. **Business Model** — if detectable from PRODUCT.md, else placeholder
9. **Team** — placeholder (user fills in)
10. **Ask** — placeholder (user fills in)

#### docs/ONE-PAGER.md (--one-pager or no flags)

Single-page product overview (fits one printed page):
- Product name + one-liner
- The Problem (2-3 sentences)
- The Solution (2-3 sentences)
- Key Capabilities (4-6 bullets)
- Who It's For (role list with one-line descriptions)
- How It Works (3 steps)
- Why Us (differentiators from PRODUCT.md)

#### docs/PRODUCT-DOCS.md (no flags only)

Technical reference for evaluators.

Sections:
- **Architecture Overview** — stack, auth, data model, tenant isolation
- **User Roles Reference** — table: Role | Tier | Primary Function | Key Modules
- **Module Reference** — one section per major module
- **API & Integration** — webhooks, API keys, event types
- **Security & Compliance** — isolation, audit log, RBAC, impersonation
- **Configuration** — platform settings, environment

### Phase 3 — Commit

```bash
git checkout develop && git pull origin develop
git add docs/SALES-PLAY.md docs/PRODUCT-BROCHURE.md docs/DEMO-SEQUENCE.md \
        docs/API-REFERENCE.md docs/ARCHITECTURE.md docs/ONBOARDING.md \
        docs/PITCH-DECK.md docs/ONE-PAGER.md docs/PRODUCT-DOCS.md 2>/dev/null || true
git commit -m "docs: generate pitch artifacts

/vb-pitch [flags used]
Sources: PRODUCT.md, Highlights Index issue, codebase scan"
git push origin develop
```

Only add files that were actually generated.

### Phase 4 — Summary

```
/vb-pitch COMPLETE
════════════════════════════════════════════════════════
Scope:     [all | sales | dev | investor | one-pager]

Artifacts written:
  [list each file generated]

Sources used:
  docs/PRODUCT.md           [present]
  Highlights Index (GH Issue)  [N cycle comments | no data]
  Codebase scan             [N routes, N models, N API endpoints]

Committed: [sha] → develop
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Grounded artifacts** — every claim traceable to PRODUCT.md, Highlights Index issue, or codebase scan
2. **No invented proof points** — if data is missing, say so honestly
3. **Overwrite existing** — regenerate fresh each run
4. **Read before writing** — read all source files before generating any artifact
5. **Consistent voice** — sales: benefit-led, no jargon. Dev: precise, no fluff
6. **Honest gaps** — Known Gaps section in sales play is mandatory and accurate
7. **Mermaid for diagrams** — no external image dependencies
8. **One commit** — all doc artifacts in a single commit
9. **Metrics are data-driven** — every metric comes from GitHub Issues, no guessing
10. **Status is read-only** — `--status` never writes files or creates issues
