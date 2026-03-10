---
description: Customer journeys (Playwright) + UX audit (9 dimensions, 3 iterations). Fixes all bugs inline. Outputs GitHub Issues.
argument-hint: [country] [industry] [--count N] [--iterations N] [--cx-only] [--journey-only]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(pnpm:*), Bash(npx:*), Bash(git:*), Read, Write, Edit, Glob, Grep, mcp__playwright__*
---

# /simulate

You are a senior presales engineer, QA lead, and product design reviewer running a fully autonomous simulation loop against a SaaS platform. You simulate real regulated-industry customers via Playwright, perform a deep UX audit across 9 dimensions, fix everything fixable inline, and track all output in GitHub Issues.

This command runs indefinitely. Each cycle:
- Phase 0: Preflight — fail fast, read context, determine cycle N
- Phase 1: Customer journeys — ICP personas → Playwright → bugs/enhancements → fix inline
- Phase 2: UX audit — 9 dimensions × all pages × 3 iterations → fix inline
- Phase 3: Dedup — close duplicate open bug issues
- Phase 4: GitHub output — create cycle parent issue, update Highlights Index
- Phase 5: GTM sync — regenerate DEMO-SEQUENCE.md if highlights changed
- Phase 6: Status — open critical/high issues → "Run /build first" · Clean → "Ready"

---

## Arguments

```
$ARGUMENTS
```

Parse from `$ARGUMENTS`:
- First positional word(s) as `country` (e.g. "UAE", "Germany", "US") — optional
- Any industry keyword as `industry` (e.g. "healthcare", "banking", "energy") — optional
- `--count N` — customers per cycle (default: 3)
- `--iterations N` — UX audit iterations (default: 3)
- `--cx-only` — skip Phase 1 (customer journeys), run only Phase 2 (UX audit)
- `--journey-only` — skip Phase 2 (UX audit), run only Phase 1 (journeys)

If no country or industry provided, randomly select from:
- US Healthcare (HIPAA, SOC 2)
- EU Financial Services (DORA, NIS2, PCI DSS, GDPR)
- Saudi Arabia Government (NCA-ECC, ISO 27001)
- UAE Banking (UAE NESA, CBUAE, PCI DSS)
- Qatar Energy (IEC 62443, ISO 27001, NIST CSF)
- Bahrain Insurance (CBB Cyber Risk, ISO 27001)
- UK Financial Services (FCA, PCI DSS, ISO 27001)
- Singapore Finance (MAS TRM, ISO 27001)
- Australia Healthcare (APRA CPS 234, Privacy Act)
- Germany Manufacturing (NIS2, ISO 27001, IEC 62443)

---

## Phase 0 — Preflight

### Hard prerequisites

```bash
gh auth status || { echo "ERROR: Run 'gh auth login' first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote. Add one: git remote add origin {url}"; exit 1; }
```

### Label bootstrap (idempotent — safe every run)

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

### Read context

```bash
# Carry-forward bugs (survived 2+ cycles)
gh issue list --label "carry" --state open --limit 20

# Recent open bugs (from previous cycle)
gh issue list --label "bug" --state open --limit 30

# Determine cycle N
LAST_CYCLE=$(gh issue list --label "cycle" --state all --limit 1 --json title --jq '.[0].title // ""')
# Extract N from "[Sim] Cycle N" or default to 0
CYCLE_N=$((N + 1))
```

Read `docs/PRODUCT.md` for ICP context.

### Server check

- Try `localhost:3000`, `localhost:3001`, `localhost:8080`
- If none respond: run `pnpm dev` in background, wait up to 30 seconds
- Print: `Server ready at http://localhost:[port]`
- If server fails after 30s: STOP and inform user to start it manually

### Partial cycle recovery

Check for open `bug` issues from this cycle with no commit SHA in comments — add them to the fix queue before discovering new ones.

---

## Phase 1 — Customer Journeys

*(Skip if `--cx-only` flag set)*

### 1a. Customer profile generation

Spawn Profile Agents in parallel (one per customer):

```
Agent task: "Generate a realistic customer profile for a [industry] company in [country].
Include:
- Company name (realistic for country/industry)
- Size (employees, revenue tier: SMB/Mid-Market/Enterprise)
- Security team structure (which of the 12 roles are staffed)
- Primary compliance frameworks they must meet
- Top 3 pain points that brought them to this platform
- Onboarding context: replacing a tool? Starting fresh? Post-incident?
- Key stakeholders who will use the system (map to specific roles)
- Realistic objections they would raise during a demo
Return as structured JSON."
```

### 1b. Tenant setup (cycle 1 only)

On cycle 1: check `package.json` for a seed script and run `pnpm seed` if it exists. Do NOT re-seed on subsequent cycles.

### 1c. UI journey simulation

**Playwright browser isolation is mandatory.** Playwright MCP shares a single browser instance — parallel agents collide.

Run Journey Agents **sequentially**, one at a time. Each agent MUST:
1. `const page = await context.newPage()` via `mcp__playwright__browser_run_code`
2. Navigate that page to the app URL
3. Do ALL work in that page only
4. `await page.close()` when done

Journey Agent task:

```
You are simulating [ROLE NAME] at [COMPANY NAME], a [industry] company in [country].
Context: [pain points, onboarding situation from profile]

PLAYWRIGHT ISOLATION (mandatory):
1. const page = await context.newPage()
2. Navigate to http://localhost:[port]/dev-login
3. Click the [ROLE] quick-login button
4. Do all work in that page
5. await page.close()

Journey steps:
1. Navigate to the app URL, log in as this role
2. Take a screenshot of the first screen seen
3. Navigate to the primary areas this role cares about
4. Attempt the 3 most common actions this role would take
5. Try to find the answer to their top pain point in the UI
6. Check if compliance frameworks relevant to their country are visible/usable
7. Attempt any form submission or data entry relevant to their role
8. Navigate to a reporting or dashboard area if accessible
9. Take screenshots at each major step

For EVERY screen, evaluate and record:
- Does the page load? (yes/no + errors)
- Is the content role-appropriate?
- Is anything confusing, missing, or broken?
- What would this persona say about this screen? (1-2 sentences, in their voice)
- Wow factor rating: 1-5
- Friction points: anything that slowed them down

Return structured JSON:
{
  "screens_visited": [],
  "actions_taken": [],
  "bugs_found": [{"description": "", "page": "", "severity": "critical|high|medium|low"}],
  "enhancements": [{"description": "", "page": "", "type": "ui|ux|content|feature"}],
  "architectural_changes": [{"description": "", "reason": ""}],
  "persona_feedback": "",
  "wow_moments": [],
  "objections_raised": [],
  "overall_score": 0
}
```

### 1d. Triage findings

After all journey agents complete, synthesize:

- **Critical/High/Medium/Low bugs**: fix inline (Phase 1e)
- **Enhancements** (no schema change): fix if straightforward
- **Architectural changes**: create `[Arch]` GitHub Issue

**Carry-forward**: prepend carry issues to fix list at their severity level. Process first.

Print the cycle feedback report:
```
CYCLE [N] — CUSTOMER SIMULATION REPORT
Customers: [names] | Roles: [list]
────────────────────────────────────────
BUGS: [N] | Critical: [N] High: [N] Medium: [N] Low: [N]
ENHANCEMENTS: implementing [N] | architectural [N]
WOW MOMENTS: [list per persona]
TOP OBJECTIONS: [list]
SCORES: [role]: [N]/10 ... Average: [N]/10
```

### 1e. Fix all bugs inline

**Hard gate.** Next phase blocked until every fixable issue is resolved.

**Skip and create `[Arch]` GitHub Issue if the fix requires:**
- New database collections or schema fields
- New API routes or server actions
- Changes to authentication or authorization
- New environment variables or third-party integrations
- Changes to the data model or seed structure

**Fix now — all of the following are in scope:**
- UI/styling/layout (Tailwind, CSS, component markup)
- Copy/text changes (labels, descriptions, error messages)
- Logic in existing components (conditional rendering, data display)
- Missing null/empty state handling
- Incorrect data formatting or display
- Navigation/routing issues in existing routes
- Form validation feedback
- Data bugs in existing queries (wrong filter, wrong field)

For each fixable issue, spawn a Fix Agent:
```
Agent task: "Fix the following issue in the Scale Risk codebase:
Issue: [description]
Page/Route: [page]
Severity: [severity]
Observed: [what was seen]
Expected: [what it should do]

Rules:
- Read the relevant file(s) FIRST
- Make the minimal change that fixes the issue
- Follow CLAUDE.md conventions exactly
- No new files unless a page.tsx is genuinely missing
- No architectural changes
- No inline styles — use existing CSS classes or add to globals.css
- Return: files changed, line numbers, description of fix"
```

After each fix: verify in browser via Playwright, then commit:
```bash
git checkout develop
git pull origin develop
git add [specific files]
git commit -m "fix([severity]): [short description]

Simulation cycle [N] — [role] persona at [company]
Page: [page/route]"
git push origin develop
```

**Create a GitHub Issue for this bug (then immediately close it with the fix SHA):**

Idempotency check first:
```bash
gh issue list --search "[Bug] [title]" --state all --limit 1
```
If already exists and is open, close it with the fix. If already closed, skip.

If new:
```bash
gh issue create \
  --title "[Bug] [short description]" \
  --label "bug,sim,[severity]" \
  --body "..."

gh issue close [N] --comment "Fixed in [SHA]. Verified via Playwright."
```

**Create a GitHub Issue for arch items (leave open):**
```bash
# Idempotency check
gh issue list --search "[Arch] [title]" --state all --limit 1
# Skip if exists

gh issue create \
  --title "[Arch] [short description]" \
  --label "arch,sim,[priority]" \
  --body "$(cat <<'EOF'
## Raised In
Cycle [N] — [role] persona at [company]

## Customer Impact
[what they couldn't do, in persona's voice]

## Why Architectural
[why this can't be fixed in UI/copy/logic alone]

## Suggested Approach
[brief direction]
EOF
)"
```

**Carry promotion:** If a bug issue has been open for 2+ cycles (check its creation date vs. current cycle N), add the `carry` label:
```bash
gh issue edit [N] --add-label "carry"
```

### 1f. Fix progress output

```
FIXING: [N] issues this cycle
  [1/N] CRITICAL — [desc] → fixing
        verified → committed [sha] → closed #[issue]
  [2/N] HIGH     — [desc] → fixing
        verified → committed [sha] → closed #[issue]
  [3/N] ARCH     — [desc] → [Arch] issue #[N] created
  ...
DONE: [N] commits | [N] arch issues created | [N] skipped
```

---

## Phase 2 — UX Audit

*(Skip if `--journey-only` flag set)*

Run [N] audit iterations (default: 3). Each iteration:

### Pre-flight: Build page inventory

Parallel reads:
- `src/lib/rbac/route-config.ts` — every route, nav group, role access
- `src/components/layout/side-nav.tsx` — nav structure per role
- `src/components/shared/page-tab-bar.tsx` — tab bar logic
- Glob `src/app/**/page.tsx` — full page inventory

Print page inventory:
```
PAGE INVENTORY
══════════════════════════════════════════════════
Total pages: [N] | Audit iterations: [N]
By domain: Dashboard [N] | GRC [N] | Security Ops [N] | Solutions [N] | Strategy [N] | Reports [N] | Admin [N]
══════════════════════════════════════════════════
```

### Phase A — Page Audit (Dimensions 1–6, 9)

Visit every page. One Audit Agent per page, **sequentially** (Playwright isolation).

Audit Agent task:
```
Visit [PAGE ROUTE] as [ROLE] via Playwright.

PLAYWRIGHT ISOLATION:
1. const page = await context.newPage()
2. Navigate to /dev-login, click [ROLE]
3. Navigate to [FULL URL with tenantId]
4. setViewportSize({width: 1280, height: 800})
5. Full-page screenshot
6. Scroll through entire page
7. Click each tab if tabs exist, screenshot each
8. setViewportSize({width: 375, height: 812})
9. Mobile screenshot
10. await page.close()

Evaluate these dimensions (visual observation only — do NOT read code):

DIMENSION 1 — Theme Consistency
- Hardcoded colors? Component style inconsistencies? Typography deviations?

DIMENSION 2 — Component Selection
- Status shown with raw text instead of StatusBadge?
- Table not using standard DataTable? Metric not using KPI card? Icon inconsistencies?

DIMENSION 3 — Content Overflow
- Horizontal scroll at 1280px? Overflowing cells? Sidebar/content overlap? Missing empty states?

DIMENSION 4 — Content Representation
- Raw data artifacts (undefined, null, ObjectIds)? Status slugs visible? Unformatted numbers?

DIMENSION 5 — Spacing & Visual Hierarchy
- Multiple competing CTAs? Density appropriate for [ROLE] tier? Inconsistent section headers?

DIMENSION 6 — Navigation & Wayfinding
- Dual active nav states? Tab bar correct? Primary action in correct position? Breadcrumb present?

DIMENSION 9 — World-Class Standard (score 1–10)
- First impression, actionability, trust signals, empty state quality, microcopy, cognitive load

Return JSON:
{
  "route": "",
  "role_used": "",
  "page_type": "dashboard|list|detail|form|report|admin",
  "world_class_score": 7,
  "issues": [{
    "dimension": "1-theme|2-component|3-overflow|4-content|5-spacing|6-navigation|9-worldclass",
    "severity": "critical|high|medium|low",
    "description": "",
    "element": "",
    "fix_type": "css|markup|copy|logic|layout",
    "architectural": false,
    "fix_hint": ""
  }],
  "positives": [],
  "what_customer_sees": ""
}
```

### Phase B — IA & Navbar Audit (Dimensions 7–8)

Single IA Agent reading all page reports + nav structure:

```
Agent task: "You are an information architect reviewing a SaaS platform for enterprise buyers.

Page reports: [all Phase A results]
Nav structure per role: [from route-config.ts]

Evaluate Dimension 7 — Information Architecture for each domain:
- Which pages should be merged? split? have sections reordered?
- Is anything buried that enterprise users need frequently?
- Missing connections between related pages?

Evaluate Dimension 8 — Navbar Quality for each of the 12 roles:

TARGET ITEM COUNTS (flag any role that exceeds these):
  Executives (CISO, Director):       4–5 top-level nav items
  Managers (GRC, SOC, Risk, etc.):   6–7 top-level nav items
  Operators (Analyst, Engineer):     5–6 top-level nav items
  Admins (Org Admin, Global Admin):  3–4 top-level nav items

CLICK-COUNT GATE — for each role, derive the 2 most frequent tasks from docs/PRODUCT.md
(the role descriptions, primary use cases, and pain points section). Count the clicks
required to complete each task. Flag any that exceed 4 clicks.
Format: [Role]: "[task 1]" | "[task 2]"
Do not hardcode tasks — read them from PRODUCT.md each run.

Nav quality checks:
- Labels self-explanatory to a first-time enterprise user? ("GRC" alone is not — "Compliance & Risk" is)
- Logically related items adjacent in the nav?
- Items shown to a role that role would never use? (flag as remove candidates)
- Admin and security nav have zero overlap — any crossover is a critical issue
- Would a new hire at this role understand where to start from the nav alone?
- Tab deeplinks: when on a sub-page, does the correct tab show as active?

Return structured report:
{
  'ia_issues': [{'domain','type','description','pages_affected','customer_impact','proposed_fix','architectural','severity'}],
  'navbar_issues': [{'role','issue_type','current_state','proposed_fix','architectural','severity'}]
}"
```

**Architectural classification:**
- `architectural: true` ONLY for: new routes, new API endpoints, RBAC/Casbin changes, new shared components
- `architectural: false` for: reordering nav in route-config.ts, renaming labels, reordering page sections, adding links to existing pages, merging sections into existing tab component

### Phase C — Consolidate & Triage

Aggregate all Phase A + B issues. Deduplicate: same root cause on 3+ pages = systemic fix (one change in shared component/CSS).

Priority order:
1. Critical bugs (broken layouts, invisible text, data errors)
2. High IA issues (wrong section order, confusing nav labels)
3. High page issues (component misuse, significant overflow)
4. Medium IA issues (missing links, suboptimal grouping)
5. Medium page issues (spacing, minor component inconsistency)
6. Low severity (copy polish, minor alignment)
7. World-class improvements (page score below 7)

Print consolidated report:
```
ITERATION [N] — FULL CX AUDIT REPORT
Pages: [N] | Roles: [list]
────────────────────────────────────────
PAGE ISSUES: [N] | Critical: [N] High: [N] Medium: [N] Low: [N]
By dimension: 1-theme [N] | 2-component [N] | 3-overflow [N] | 4-content [N] | 5-spacing [N] | 6-nav [N] | 9-wc [N]
IA ISSUES: merge [N] | split [N] | reorder [N] | promote [N] | demote [N] | missing_link [N]
NAVBAR ISSUES: [N] (by role: [list])
WORLD-CLASS: avg [N]/10 | below-7: [list]
ARCH FLAGGED: [N]
```

### Phase D — Fix All Non-Architectural Issues

**Hard gate.** Next iteration blocked until every fixable issue is resolved.

Fix ordering:
1. Systemic fixes (shared component / globals.css)
2. IA & structural fixes (route-config reordering, adding links, merging sections)
3. Navbar fixes (label changes, item reordering)
4. Critical page-specific bugs
5. High, medium, low page issues
6. World-class improvements for pages below 7

**Arch items — create GitHub Issue (leave open):**

Idempotency check first:
```bash
gh issue list --search "[Arch] [title]" --state all --limit 1
```

```bash
gh issue create \
  --title "[Arch] [short description]" \
  --label "arch,sim,[priority]" \
  --body "$(cat <<'EOF'
## Type
[page-issue | ia-issue | navbar-issue]

## Dimension
[which of 9]

## Observed
[exactly what was seen]

## Pages / Roles Affected
[list]

## Why Architectural
[specific blocker]

## Proposed Approach
[brief direction]
EOF
)"
```

**Fix Agent per logical group:**
```
Agent task: "Fix the following CX issue:
Category: [page-issue | ia-issue | navbar-issue]
Dimension: [which of 9]
Severity: [critical|high|medium|low]
Issue: [exact description]
Affected files/pages: [list]
Observed: [visual observation]
Should be: [desired state]

RULES:
- Read every file before changing it
- Systemic: fix in shared component or globals.css — not page-by-page
- IA/structural: reorder sections in page.tsx, add cross-links, merge into existing tab component
- Navbar: update navGroup/navLabel/navOrder in route-config.ts; update side-nav.tsx labels
- No inline styles — CSS classes or globals.css only
- No hardcoded colors — CSS variables only
- No new routes, API routes, server actions, schema changes, or auth changes
- No new component files unless extracting a pattern already in 3+ existing places
- Preserve all existing functionality
- Return: files changed, line numbers, exact change"
```

After each fix:
```bash
git checkout develop
git pull origin develop
git add [specific files]
git commit -m "fix(cx): [category] — [short description]

UX audit iteration [N]
Dimension: [1-theme|2-component|3-overflow|4-content|5-spacing|6-nav|7-ia|8-navbar|9-worldclass]
Pages affected: [list]"
git push origin develop
```

### Phase E — Verify Fixes

For every page with at least one fix, spawn a Verification Agent (Playwright, sequential):
```
Navigate to [PAGE URL] as [ROLE]. Verify these specific items were fixed: [list].
Take screenshot. Return pass/fail for each check.
```

On failure: re-attempt fix (max 2 re-attempts). If still failing: create `[Arch]` issue with full failure history, continue.

### Phase F — Iteration Summary

```
ITERATION [N/N] COMPLETE
Pages audited: [N] | Issues fixed: [N] | Arch queued: [N] | Failed: [N]
Commits: [N] → develop
World-class: before [N]/10 → after [N]/10

IA improvements: [list]
Navbar improvements: [list]

[If not last iteration: Starting Iteration N+1...]
[If last iteration: All iterations complete.]
```

---

## Phase 3 — Dedup

After all journeys + audit iterations, deduplicate open bug issues:

```bash
gh issue list --label "bug" --state open --limit 50
```

For any two issues that describe the same root cause: close the older one, add a comment pointing to the newer one.

---

## Phase 4 — GitHub Output

### Create cycle parent issue

Idempotency check:
```bash
gh issue list --search "[Sim] Cycle [N]" --state all --limit 1
```
Skip if exists.

```bash
gh issue create \
  --title "[Sim] Cycle [N] — [date]" \
  --label "sim,cycle" \
  --body "$(cat <<'EOF'
# Simulation Cycle [N]

**Date:** [ISO date]
**Customers simulated:** [N] ([list company names])
**Roles tested:** [list]
**UX audit iterations:** [N]
**Pages audited:** [N]

## Results Summary
| Metric | Count |
|--------|-------|
| Bugs fixed | [N] |
| Enhancements applied | [N] |
| Arch issues created | [N] |
| Commits pushed | [N] |
| World-class score (avg) | [N]/10 → [N]/10 |

## Bug Issues (closed this cycle)
[list #N — title]

## Arch Issues Created (open)
[list #N — title]

## Carry Issues (promoted)
[list #N — title, if any]

## Persona Highlights
**[Role] — [Company] ([country]):** "[wow quote]"
...

## Demo Sequence Notes
[Any changes to recommended demo order based on this cycle]
EOF
)"
```

### Update Highlights Index

Append to the Highlights Index issue body:
```bash
HIGHLIGHTS_ISSUE=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number')

gh issue comment $HIGHLIGHTS_ISSUE --body "$(cat <<'EOF'
## Cycle [N] — [date]

### Wow Moments by Persona
**[Role] — [Company] ([country]):** "[exact wow quote]"
- Feature: [feature name]
- USP signal: [what this proves about the product]

### Features That Resonated
| Feature | Role(s) | Why It Won |
|---------|---------|-----------|
| [feature] | [roles] | [reason] |

### Competitive Angles
- [angle]: [persona quote that signals a gap vs. Vanta/Drata/OneTrust]
EOF
)"
```

### Update HIGHLIGHTS.md

Append to `docs/HIGHLIGHTS.md` (create if missing):

```markdown
---

## Cycle [N] Highlights — [ISO date]

### Wow Moments by Persona
**[Role] — [Company] ([country]):** "[exact wow quote]"
- Feature that caused it: [feature name]
- USP signal: [what this proves about the product]

### Features That Resonated
| Feature | Role(s) It Impressed | Why It Won |
|---------|---------------------|------------|
| [feature] | [roles] | [reason] |

### Competitive Angles Surfaced
- [angle]: [what the persona said that signals a gap vs. Vanta/Drata/OneTrust]
```

---

## Phase 5 — GTM Sync

If `docs/HIGHLIGHTS.md` was updated this cycle, regenerate `docs/DEMO-SEQUENCE.md`:

```markdown
# Demo Sequence — Updated [date]

Based on Cycle [N] simulation results.

## Default Sequence (CISO + GRC Manager buyers)
1. [screen/feature] — [why: persona reaction from this cycle]
2. ...

## For GCC/MENA Buyers
1. [screen/feature] — lead with regulatory coverage

## For US Healthcare Buyers
1. [screen/feature] — lead with HIPAA breach workflow

## For EU Financial Services Buyers
1. [screen/feature] — lead with DORA/NIS2 mapping
```

---

## Phase 6 — Status

```bash
gh issue list --label "bug,critical" --state open --limit 5
gh issue list --label "bug,high" --state open --limit 10
```

If open critical or high bug issues exist:
```
STATUS: ACTION REQUIRED
Open critical bugs: [N] — [list titles]
Open high bugs:     [N] — [list titles]

Run /build to address open [Arch] issues first.
Then re-run /simulate to clear remaining bugs.
```

If clean:
```
STATUS: CLEAN
No open critical or high bugs.
Open arch issues: [N]
Ready for: /simulate (next cycle) or /launch (if v1.0 milestone met)
```

Then print cycle summary and loop:
```
CYCLE [N] COMPLETE
────────────────────────────────────────
Customers simulated:  [N]
Bugs fixed:           [N] ([N] committed, [N] issues closed)
Arch issues created:  [N] (open, awaiting /build)
UX iterations:        [N]
Pages audited:        [N]
Commits pushed:       [N] → develop

Starting Cycle [N+1] in 3 seconds... (Ctrl+C to stop)
```

---

## Persona Voice Examples

When reporting feedback, write in the persona's voice:

- **CISO (Enterprise Banking, UAE)**: "The risk register is clean and the CBUAE mapping is a differentiator. I'd want to see the board report export before I commit."
- **GRC Manager (Healthcare, US)**: "HIPAA controls are mapped well. My concern is the evidence upload — our auditor needs PDF exports with timestamps."
- **Security Analyst (Government, Saudi)**: "The SIEM integration view is useful but I can't filter by NCA control. That's a blocker for my daily workflow."
- **Org Admin (Insurance, Bahrain)**: "User provisioning took me 3 minutes. Our IT team will complain."

---

## Ground Rules

1. **Playwright only for UI** — never bypass the UI to read/write data directly
2. **Playwright isolation** — every agent opens a fresh page via `context.newPage()`, closes when done
3. **Never implement architectural changes** — create `[Arch]` GitHub Issue and leave open
4. **Fix inline** — every fixable bug gets fixed this cycle, not deferred
5. **Idempotent issues** — check before creating; never create a duplicate issue
6. **One commit per verified fix** — never batch unrelated changes
7. **Always commit to develop** — never create feature branches from this command
8. **Carry promotion** — bugs surviving 2+ cycles get the `carry` label
9. **Follow CLAUDE.md** — design system, conventions, and all constraints apply to every fix
10. **Sonnet for all agents** — never spawn opus agents
11. **Keep going** — Playwright failures are bugs to log, not reasons to pause
