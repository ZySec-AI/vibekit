---
description: Customer journeys (Playwright) + UX audit (9 dimensions, 3 iterations). Fixes all bugs inline. Outputs GitHub Issues.
argument-hint: [country] [industry] [--count N] [--iterations N] [--cx-only] [--journey-only]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(pnpm:*), Bash(npx:*), Bash(git:*), Bash(curl:*), Bash(uv:*), Read, Write, Edit, Glob, Grep
---

# /vb-simulate

You are a senior presales engineer, QA lead, and product design reviewer running a fully autonomous simulation loop against a web application. You simulate real customers via Playwright, perform a deep UX audit across 9 dimensions, fix everything fixable inline, and track all output in GitHub Issues.

Runs indefinitely (Ctrl+C to stop). Branch: always `develop`. PRs merged with `--delete-branch`.

---

## Arguments

```
$ARGUMENTS
```

- First positional word(s) → `country` (optional)
- Any industry keyword → `industry` (optional)
- `--count N` — customers per cycle (default: 3)
- `--iterations N` — UX audit iterations (default: 3)
- `--cx-only` — UX audit only, skip journeys
- `--journey-only` — journeys only, skip UX audit

If no country/industry: read `docs/PRODUCT.md` → derive the top ICP profiles from the ICP section.
**Never hardcode a country or industry list. Always read from PRODUCT.md.**

---

## Phase 0 — Preflight

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

### Label check

```bash
gh label list --limit 1 --json name --jq '.[0].name' 2>/dev/null | grep -q "sim" || {
  echo "Labels not found — run /vb-setup first."; exit 1;
}
```

### Load project board + milestone config

```bash
PROJECT_CONFIGURED=false
[ -f ".vibekit/project.env" ] && source .vibekit/project.env || true
MILESTONE_TITLE=""
[ -f ".vibekit/milestone.env" ] && source .vibekit/milestone.env || true
```

Define `add_to_project()` helper — used to place issues onto the Kanban board:
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

### Read PRODUCT.md (required)

Read `docs/PRODUCT.md`. If missing → print "Run /vb-setup first." and exit.

Extract and hold in context for the entire session:
- **ICP** — who the buyers are, industry verticals, geographies
- **Roles** — every named user role in this product (do not assume role names)
- **Role tasks** — primary use cases per role (used for click-count gate in Dimension 8)
- **Competitive context** — used to evaluate objections

### Detect cycle number

```bash
LAST=$(gh issue list --label "cycle" --state all --limit 1 --json title --jq '.[0].title // ""')
# Parse N from "[Sim] Cycle N", default 0, set CYCLE_N=$((N+1))
```

Pull carry-forward bugs: `gh issue list --label "carry" --state open --limit 20`
Pull open bugs: `gh issue list --label "bug" --state open --limit 30`

### Detect dev server

Try ports 3000, 3001, 5173, 8000, 8080, 4000, 4200, 8888 with a quick curl.
If none respond, detect stack and start the server:

```bash
if   [ -f "pnpm-lock.yaml" ] || [ -f "package.json" ]; then CMD="pnpm dev"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then CMD="uv run dev"
else CMD=""; fi
```

Node projects use `pnpm dev`. Python projects use `uv run dev` (or `uv run uvicorn main:app` if no dev script detected in pyproject.toml).

Run background, wait up to 30s. Print `Server ready at http://localhost:[port]`.
If still no server: STOP, tell user to start it manually.

### Detect login mechanism

Read the codebase to discover how to authenticate:
- Dev/quick-login page (e.g. `/dev-login`, `/__dev/login`, `/auth/bypass`)
- Standard form (look for login route + seed credentials in README/CLAUDE.md/scripts/)
- OAuth

Record the exact login path and method — Playwright agents will use this.

### Partial cycle recovery

Find open `bug` issues with no commit SHA in comments → add to fix queue before discovering new ones.

### Print preflight summary

```
PREFLIGHT — CYCLE [N]
══════════════════════════════════════════════════
  Carry bugs:     [N]
  Open bugs:      [N]
  Server:         http://localhost:[port]
  Login:          [method — e.g. "form at /login with seed creds" or "dev-login at /dev-login"]
  Customers:      [N] (from --count or default 3)
══════════════════════════════════════════════════
```

---

## Phase 1 — Customer Journeys

*(Skip if `--cx-only`)*

### 1a. Profile generation

Derive all persona attributes from `docs/PRODUCT.md`. Spawn one Profile Agent per customer, in parallel:

```
Generate a realistic customer profile for this product.
ICP from PRODUCT.md: [paste ICP section]
Roles from PRODUCT.md: [paste roles]
Country: [if specified] | Industry: [if specified, else pick most relevant from ICP]

Return JSON with: company name, size, staffed roles (use exact role names from PRODUCT.md),
pain points, onboarding context, stakeholders, likely objections.
```

Print after profiles are generated:
```
PROFILES GENERATED
══════════════════════════════════════════════════
  [1] [Company] — [Industry], [Size] — Roles: [list]
  [2] [Company] — [Industry], [Size] — Roles: [list]
  [3] [Company] — [Industry], [Size] — Roles: [list]
══════════════════════════════════════════════════
```

### 1b. Seed (cycle 1 only)

```bash
# Only on cycle 1
cat package.json 2>/dev/null | grep -q '"seed"' && [package-manager] seed || true
```

### 1c. UI journey simulation

**All browser automation uses `npx playwright` — sequential, one browser process at a time. No MCP. No parallel tabs.**

Each journey runs as a self-contained Node.js script executed via `npx playwright`:

```bash
# Playwright check (setup already installed, but verify)
npx playwright --version 2>/dev/null || npx playwright install chromium --with-deps
```

Write a temporary script `.vibekit/_pw_journey_[N].mjs` for each journey:

```js
// .vibekit/_pw_journey_[N].mjs
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();

// 1. Auth — use detected login mechanism
// 2. Navigate to role-owned areas (from PRODUCT.md)
// 3. Attempt the 3 most common actions for this role
// 4. Try to find the answer to their top pain point
// 5. Submit a relevant form or data entry
// 6. Visit a reporting/dashboard area if accessible
// 7. Screenshot at each major step: await page.screenshot({ path: '.vibekit/_pw_[N]_[step].png' })

// Collect findings
const result = {
  screens_visited: [],
  bugs_found: [],        // [{description, page, severity}]
  enhancements: [],      // [{description, page, type}]
  architectural_changes: [], // [{description, reason}]
  persona_feedback: '',
  wow_moments: [],
  objections_raised: [],
  overall_score: 0
};

await browser.close();
console.log(JSON.stringify(result));
```

```bash
node .vibekit/_pw_journey_[N].mjs > .vibekit/_pw_journey_[N].json
```

Read the JSON output. Delete temp files after reading:
```bash
rm -f .vibekit/_pw_journey_[N].mjs .vibekit/_pw_journey_[N].json .vibekit/_pw_[N]_*.png
```

Journey Agent prompt (spawn one agent per journey, sequential):
```
You are [ROLE from PRODUCT.md] at [COMPANY], a [industry] company in [country].
Pain points: [from profile]. Login: [detected mechanism]. Server: http://localhost:[port]

Write .vibekit/_pw_journey_[N].mjs using the template above. Fill in:
- Auth steps for detected login mechanism
- Navigation targets matching this role's areas (from PRODUCT.md)
- The 3 most common actions for this role
- Screenshots named descriptively

Run it. Read the JSON. Report findings.
For every screen: load status, role-appropriateness, persona quote (in their voice), wow-factor 1-5, friction points.
```

Print after each journey completes:
```
JOURNEY [1/N]: [Role] at [Company] — Pages: [N] | Bugs: [N] | Score: [N]/10
```

### 1d. Triage

Synthesize all journey reports. Carry-forward bugs go first at their original severity.

```
CYCLE [N] — SIMULATION REPORT
══════════════════════════════════════════════════
Customers: [names] | Roles: [list]
BUGS: [N] | Critical: [N] High: [N] Medium: [N] Low: [N]
ENHANCEMENTS: implementing [N] | architectural [N]
WOW MOMENTS: [per persona] | TOP OBJECTIONS: [list]
SCORES: [role: N/10 ...] Average: [N]/10
══════════════════════════════════════════════════
```

### 1e. Fix all bugs inline

**Hard gate — all fixable issues must be resolved before moving on.**

**Architectural (create `[Arch]` issue, do not fix):** new DB schema, new API routes, auth/permission changes, new env vars, data model changes.

**Fix now:** UI/CSS/layout, copy, component logic, null/empty states, data formatting, routing in existing routes, form validation, query filter bugs.

Fix Agent per issue:
```
Fix this issue in the codebase.
Issue: [desc] | Page: [route] | Severity: [sev]
Observed: [what] | Expected: [what]

Rules: read CLAUDE.md if present → read files before editing → minimal change →
follow existing conventions → no new files unless route genuinely missing →
no arch changes → no inline styles → return files changed + line numbers.
```

After each fix, verify via `npx playwright` script, then commit:

```bash
git checkout develop
git pull origin develop
git add [specific files]
git commit -m "fix([severity]): [short description]

Simulation cycle [N] — [role] at [company]
Page: [route]"
git push origin develop
```

Print after each fix:
```
FIX [1/N]: [short description] — [severity] — [sha]
```

Create + immediately close a GitHub Issue per bug:

**Title format:** `[Bug] <module>: <short description>` — e.g. `[Bug] Dashboard: chart renders empty for date ranges with no data`

```bash
# Idempotency: check before creating
gh issue list --search "[Bug] [module]: [short desc]" --state all --limit 1 --json number --jq '.[0].number // empty'
# If empty → create with structured body, then close with SHA comment
BUG_URL=$(gh issue create \
  --title "[Bug] [module]: [short description]" \
  --label "bug,sim,[severity]" \
  --body "## Summary
[one-sentence description of what's wrong]

## Steps to Reproduce
1. Login as [role]
2. Navigate to [route]
3. [action that triggers the bug]

## Observed
[what actually happens — e.g. 'Chart shows empty container with no message']

## Expected
[what should happen — e.g. 'Empty state message: No data for this range']

## Severity: [critical|high|medium|low]

## Context
- **Page:** [route]
- **Role:** [role that encountered it]
- **Customer:** [persona name] at [company]
- **Cycle:** ${CYCLE_N}
" --json url --jq '.url')
BUG_NUM=$(echo "$BUG_URL" | grep -oE '[0-9]+$')
# Assign milestone if configured
[ -n "$MILESTONE_TITLE" ] && [ -n "$BUG_NUM" ] && gh issue edit "$BUG_NUM" --milestone "$MILESTONE_TITLE" 2>/dev/null || true
gh issue close "$BUG_NUM" --comment "Fixed in [SHA]. Verified via Playwright."
# Track bug number for cycle parent tasklist
BUG_NUMS="$BUG_NUMS $BUG_NUM"
```

Create + leave open for arch items:

**Title format:** `[Arch] <module>: <what needs to be built>` — e.g. `[Arch] Auth: add role-based access control for admin routes`

```bash
gh issue list --search "[Arch] [module]: [short desc]" --state all --limit 1 --json number --jq '.[0].number // empty'
# If empty → create with structured body
ARCH_URL=$(gh issue create \
  --title "[Arch] [module]: [short description]" \
  --label "arch,sim,[priority]" \
  --body "## Summary
[one-sentence description of what needs to be built or changed]

## Why
[what user scenario or gap prompted this — reference the persona/journey]

## Scope
- [specific change 1 — e.g. 'Add RBAC middleware for /admin/* routes']
- [specific change 2 — e.g. 'Create role column in users table']
- [specific change 3]

## Affected Areas
- **Routes:** [list affected routes]
- **Models:** [list affected models/schema if any]
- **Files likely involved:** [list key files]

## Out of Scope
[anything explicitly NOT included to prevent scope creep]

## Context
- **Discovered by:** [role] at [company] during Cycle ${CYCLE_N}
- **Priority:** [critical|high|medium|low]
" --json url --jq '.url')
ARCH_NUM=$(echo "$ARCH_URL" | grep -oE '[0-9]+$')
# Assign milestone if configured
[ -n "$MILESTONE_TITLE" ] && [ -n "$ARCH_NUM" ] && gh issue edit "$ARCH_NUM" --milestone "$MILESTONE_TITLE" 2>/dev/null || true
# Add to project board in "Arch Backlog" column
add_to_project "$ARCH_URL" "Arch Backlog"
# Track arch number for cycle parent tasklist
ARCH_NUMS="$ARCH_NUMS $ARCH_NUM"
```

Carry promotion (bug open 2+ cycles):
```bash
gh issue edit [N] --add-label "carry"
```

---

## Phase 2 — UX Audit

*(Skip if `--journey-only`)*

### Page inventory discovery

Do not assume any specific file structure. Try in order:
1. Look for a route config file (`route-config.ts`, `routes.ts`, `router.tsx`, `App.tsx`, `urls.py`, `routes.rb`, `config/routes.rb`)
2. Glob for page files: `**/page.tsx`, `**/page.jsx`, `**/*.page.tsx`, `**/views.py`, `**/pages/**/*.vue`
3. Read the main nav component to extract linked routes

Build page list: route, likely role(s), page type.

```
PAGE INVENTORY
══════════════════════════════════════════════════
Total pages: [N] | Iterations: [N]
Domains (derived from routes): [list — not hardcoded]
Roles (from PRODUCT.md): [list]
══════════════════════════════════════════════════
```

### Phase A — Page Audit (Dimensions 1–6, 9)

One Audit Agent per page, sequential. Role = whichever PRODUCT.md role most logically owns it.
Auth via detected login mechanism.

```
Write `.vibekit/_pw_audit_[route_slug].mjs` for each page:

```js
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();

// Auth, navigate to route, screenshot desktop
await page.screenshot({ path: '_pw_audit_[slug]_desktop.png' });
// Scroll full page
await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
// Click each visible tab/accordion
// Switch to mobile
await page.setViewportSize({ width: 375, height: 812 });
await page.screenshot({ path: '_pw_audit_[slug]_mobile.png' });

const result = {
  route: '[ROUTE]', role_used: '[ROLE]', page_type: '[type]',
  world_class_score: 0,  // 1-10
  issues: [],   // [{dimension, description, severity, fixable}]
  positives: [],
  what_customer_sees: ''
};
await browser.close();
console.log(JSON.stringify(result));
```

```bash
node .vibekit/_pw_audit_[route_slug].mjs > .vibekit/_pw_audit_[route_slug].json
rm -f .vibekit/_pw_audit_[route_slug].mjs .vibekit/_pw_audit_[route_slug].json .vibekit/_pw_audit_[route_slug]_*.png
```

Audit Agent evaluates from screenshots (visual only, no code reading):

D1 Theme: hardcoded colors? mixed visual styles? typography inconsistencies?
D2 Components: same data shown differently in different places? status as raw text vs badges?
D3 Overflow: horizontal scroll at 1280px? missing empty states?
D4 Content: raw null/undefined/slugs? unformatted numbers/dates?
D5 Hierarchy: competing CTAs? density matches role tier?
D6 Wayfinding: dual active nav? breadcrumb present? primary action position consistent?
D9 World-class (1–10): first impression, actionability, trust signals, microcopy, cognitive load

Return JSON with route, role_used, page_type, world_class_score, issues[], positives[], what_customer_sees.
```

Print after each page audit:
```
AUDIT [1/N]: [route] — Score: [N]/10
```

### Phase B — IA & Navbar Audit (Dimensions 7–8)

Single IA Agent with all Phase A results + nav structure:

```
You are an information architect. Evaluate:

D7 Information Architecture (per domain derived from routes):
- Pages to merge, split, reorder, promote, demote, or add links between?
- Most important info first on each page?

D8 Navbar Quality (per role from PRODUCT.md):
Target counts: leadership 4–5 | managers 6–7 | operators 5–6 | admins 3–4
Click-count gate: derive 2 most frequent tasks per role FROM PRODUCT.md role descriptions.
Count clicks. Flag any exceeding 4. Never hardcode the tasks.
Label clarity, related items adjacent, role-appropriate items only, new hire discoverability.

architectural: true only for new routes/APIs/auth/missing components.
architectural: false for reordering, renaming, restructuring existing pages/nav.
```

### Phase C — Consolidate

Same root cause on 3+ pages = one systemic fix.
Priority: Critical → High IA → High page → Medium → Low → World-class <7.

### Phase D — Fix Non-Architectural Issues

Fix Agent per logical group:
```
Fix this UX issue. Category: [type] | Dimension: [N] | Severity: [sev]
Read CLAUDE.md if present. Read files before editing.
Systemic: fix in shared component / main stylesheet.
IA: reorder sections, add cross-links, merge into existing tab component.
Navbar: update route config / nav component labels and order.
No inline styles. No hardcoded colors. No new routes/APIs/schema/auth changes.
No new components unless pattern exists in 3+ places already.
```

Commit per fix group:
```bash
git checkout develop && git pull origin develop
git add [files] && git commit -m "fix(cx): [desc]

UX audit iteration [N] | Dimension: [N] | Pages: [list]"
git push origin develop
```

Print after each CX fix:
```
CX FIX [1/N]: [short description] — Dimension [N]
```

### Phase E — Verify

Run a targeted `npx playwright` script per fixed page — navigate to the route, screenshot, confirm the issue is gone. On failure: re-attempt fix max 2x. Still failing → `[Arch]` issue with history.

### Phase F — Summary

```
ITERATION [N/N] COMPLETE
Pages: [N] | Fixed: [N] | Arch: [N] | Failed: [N] | Commits: [N] → develop
World-class: [before]/10 → [after]/10
```

---

## Phase 3 — Performance Audit

Collect Core Web Vitals and load timing for every page in the inventory using Playwright's CDP (Chrome DevTools Protocol). Run sequentially — one script per page.

Write `.vibekit/_pw_perf_[route_slug].mjs`:

```js
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

// Enable CDP for performance metrics
const cdp = await context.newCDPSession(page);
await cdp.send('Performance.enable');

// Auth (same mechanism as journeys)
// Navigate to route
await page.goto('http://localhost:[port][ROUTE]', { waitUntil: 'networkidle' });

// Collect metrics via CDP
const metrics = await cdp.send('Performance.getMetrics');
const navTiming = await page.evaluate(() => JSON.stringify(window.performance.timing));
const paintTiming = await page.evaluate(() =>
  JSON.stringify(performance.getEntriesByType('paint'))
);
const lcp = await page.evaluate(() =>
  new Promise(resolve => {
    new PerformanceObserver(list => {
      const entries = list.getEntries();
      resolve(entries[entries.length - 1]?.startTime ?? null);
    }).observe({ type: 'largest-contentful-paint', buffered: true });
    setTimeout(() => resolve(null), 3000);
  })
);
const cls = await page.evaluate(() =>
  new Promise(resolve => {
    let clsScore = 0;
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) clsScore += entry.value;
    }).observe({ type: 'layout-shift', buffered: true });
    setTimeout(() => resolve(clsScore), 2000);
  })
);

const result = {
  route: '[ROUTE]',
  lcp_ms: lcp,          // Largest Contentful Paint — threshold: <2500ms good, >4000ms poor
  cls_score: cls,        // Cumulative Layout Shift — threshold: <0.1 good, >0.25 poor
  tti_ms: null,          // Time to Interactive (from navTiming: domInteractive - navigationStart)
  fcp_ms: null,          // First Contentful Paint (from paintTiming)
  total_blocking_ms: null // from CDP ScriptDuration
};

await browser.close();
console.log(JSON.stringify(result));
```

```bash
node .vibekit/_pw_perf_[route_slug].mjs > .vibekit/_pw_perf_[route_slug].json
rm -f .vibekit/_pw_perf_[route_slug].mjs .vibekit/_pw_perf_[route_slug].json
```

### Thresholds

| Metric | Good | Needs work | Poor (file bug) |
|--------|------|-----------|-----------------|
| LCP | < 2500ms | 2500–4000ms | > 4000ms |
| CLS | < 0.1 | 0.1–0.25 | > 0.25 |
| FCP | < 1800ms | 1800–3000ms | > 3000ms |
| TTI | < 3800ms | 3800–7300ms | > 7300ms |

### Output

Print after scanning all pages:
```
PERFORMANCE AUDIT — [N] pages
════════════════════════════════════════════════════════
  [route]     LCP: [N]ms  CLS: [N]  FCP: [N]ms  TTI: [N]ms  [GOOD | NEEDS WORK | POOR]
  ...
  Pages with issues: [N]
════════════════════════════════════════════════════════
```

For each **Poor** metric: create a `[Bug]` GitHub Issue labeled `bug,sim,performance,[severity]`, body includes route, metric value, threshold, and suggested investigation (e.g. "large unoptimised image", "render-blocking script", "layout shift on image load").

For each **Needs work** metric: create a `[Bug]` GitHub Issue labeled `bug,sim,performance,low`.

Check before creating (idempotent):
```bash
gh issue list --search "[Bug] Performance:" --state all --limit 1 --json number --jq '.[0].number // empty'
```

Do not attempt to auto-fix performance issues — create issues only. Performance fixes require profiling context a human or `/vb-build` must provide.

---

## Phase 4 — Dedup

```bash
gh issue list --label "bug" --state open --limit 50
```
Same root cause → close older, comment pointing to newer.

---

## Phase 5 — GitHub Output

Build the cycle parent issue body with a GitHub **tasklist** linking all child issues from this cycle. This gives trackable progress directly on the parent:

```bash
# Build tasklist from bug + arch issues created this cycle
TASKLIST=""
for NUM in $BUG_NUMS; do
  [ -n "$NUM" ] && TASKLIST="${TASKLIST}\n- [x] #${NUM}"
done
for NUM in $ARCH_NUMS; do
  [ -n "$NUM" ] && TASKLIST="${TASKLIST}\n- [ ] #${NUM}"
done

CYCLE_BODY="# Simulation Cycle ${CYCLE_N}

## Customers
| # | Company | Industry | Size | Roles Simulated |
|---|---------|----------|------|----------------|
[one row per simulated customer persona]

## Results
| Metric | Value |
|--------|-------|
| Bugs found | [N] |
| Bugs fixed inline | [N] |
| Arch issues created | [N] |
| Carry bugs (2+ cycles) | [N] |
| Pages audited | [N] |
| World-class score | [N]/10 |

## Issues
$(printf '%b' "$TASKLIST")

## Top Objections
[from persona feedback — what worried them most]

## Highlights
[genuine positive moments — what impressed the personas]
"
```

Create cycle parent issue (idempotent):
```bash
gh issue list --search "[Sim] Cycle [N]" --state all --limit 1 --json number --jq '.[0].number // empty'
# If empty → create with tasklist body
CYCLE_URL=$(gh issue create --title "[Sim] Cycle [N] — [date]" --label "sim,cycle" --body "$CYCLE_BODY" --json url --jq '.url')
CYCLE_NUM=$(echo "$CYCLE_URL" | grep -oE '[0-9]+$')
# Assign milestone if configured
[ -n "$MILESTONE_TITLE" ] && [ -n "$CYCLE_NUM" ] && gh issue edit "$CYCLE_NUM" --milestone "$MILESTONE_TITLE" 2>/dev/null || true
# Add cycle issue to project board in "Sim Queue" column
add_to_project "$CYCLE_URL" "Sim Queue"
```

Update the Highlights Index issue with a comment containing this cycle's highlights (wow moments, persona feedback, proof points). Do NOT write a local `docs/HIGHLIGHTS.md` file — the GitHub Issue is the single source of truth for highlights data.

```bash
HIGHLIGHTS_ISSUE=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
[ -n "$HIGHLIGHTS_ISSUE" ] && gh issue comment "$HIGHLIGHTS_ISSUE" --body "## Cycle ${CYCLE_N} Highlights

### Wow Moments
[list from journey + audit results — what genuinely impressed personas]

### Persona Feedback
[direct quotes from persona voice — what resonated, what surprised]

### Proof Points
[specific metrics, flows, or features that demonstrated clear value]

### Top Objections
[what worried personas — feeds into sales objection handling]
" 2>/dev/null || true
```

---

## Phase 6 — GTM Sync

If new highlights were added: regenerate `docs/DEMO-SEQUENCE.md` from the Highlights Index issue content.
Buyer types and verticals come from PRODUCT.md — never hardcoded.

```bash
# Fetch all highlights from the GitHub Issue for demo sequence generation
HIGHLIGHTS_ISSUE=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
[ -n "$HIGHLIGHTS_ISSUE" ] && HIGHLIGHTS_DATA=$(gh issue view "$HIGHLIGHTS_ISSUE" --comments --json body,comments --jq '[.body, (.comments[].body)] | join("\n---\n")' 2>/dev/null)
```

---

## Phase 7 — Status → Loop

Open critical/high? → list them, recommend `/vb-build`.
Clean → cycle summary, start Cycle N+1 in 3 seconds.

---

## Ground Rules

1. **Always `develop` branch** — all commits go to `develop`, never create feature branches
2. **npx playwright only** — all browser automation uses `npx playwright` scripts, sequential, never parallel
3. **Clean up temp files** — all scripts/screenshots go in `.vibekit/`, delete after reading output
4. **All roles from PRODUCT.md** — never assume specific role names
5. **All personas from PRODUCT.md** — never hardcode country/industry lists
6. **Read CLAUDE.md** — if it exists, read before making any fix
7. **Never implement arch changes** — GitHub Issue only, leave open
8. **Fix inline** — every fixable bug fixed this cycle
9. **Idempotent issues** — check before creating
10. **One commit per verified fix** — never batch unrelated changes
11. **Sonnet for all agents** — never spawn opus agents
12. **Keep going** — Playwright failures are bugs to log, not reasons to pause
13. **Performance issues → issues only** — never auto-fix, always create GitHub Issue
