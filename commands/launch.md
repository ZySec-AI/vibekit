---
description: Gates on open bugs, generates GTM artifacts, creates GitHub release, merges to main.
argument-hint: [--version X.Y.Z] [--dry-run]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Read, Write, Edit, Glob, Grep
---

# /launch

You are the release manager. Gate on open bugs, generate all customer-facing artifacts, create a GitHub release, merge to main.

Branch flow: `develop` → `main`. Feature branches deleted on merge.

## Arguments

```
$ARGUMENTS
```

- `--version X.Y.Z` — override version tag (default: auto-increment from latest tag)
- `--dry-run` — run all gates and generate artifacts, do NOT create release or merge

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `docs/PRODUCT.md` and `docs/HIGHLIGHTS.md` before generating any artifact.

---

## Phase 0 — Gate Check

All gates must pass. Any failure blocks the release.

### Gate 1 — No open critical or high bugs

```bash
gh issue list --label "bug,critical" --state open --limit 10 --json number,title
gh issue list --label "bug,high"     --state open --limit 10 --json number,title
```

If any exist:
```
BLOCKED: Resolve open bugs before launch.
Critical: [N] — [list titles with issue numbers]
High:     [N] — [list titles with issue numbers]
Fix: Run /simulate, or close issues with 'wontfix' label if intentionally skipping.
```
Exit. Do not proceed.

### Gate 2 — Carry bugs (warning, not blocking)

```bash
gh issue list --label "carry" --state open --limit 10 --json number,title
```
If any: list them. They appear in release notes as known issues.

### Gate 3 — Branch clean and current

```bash
git status --short
git fetch origin develop
git log HEAD..origin/develop --oneline
```
If uncommitted changes or behind remote: print diff and exit.

### Gate 4 — HIGHLIGHTS.md exists

```bash
test -f docs/HIGHLIGHTS.md && wc -l docs/HIGHLIGHTS.md
```
If missing or empty: warn (not blocking). GTM artifacts will be sparse.

Print gate summary:
```
LAUNCH GATES
════════════════════════════════════════════════════════
Gate 1 — Critical/high bugs:  PASS (0 open)
Gate 2 — Carry bugs:          [PASS | WARNING: N open]
Gate 3 — Branch clean:        PASS
Gate 4 — Highlights file:     [PASS | WARNING: empty]
All blocking gates passed. Proceeding.
════════════════════════════════════════════════════════
```

---

## Phase 1 — Version

```bash
LATEST=$(git tag --sort=-version:refname | head -1)
```

- `--version X.Y.Z` passed → use it
- No tags → `v1.0.0`
- Tags exist → increment patch (e.g. `v1.0.2` → `v1.0.3`)

Print: `Release version: [version]`

---

## Phase 2 — GTM Artifacts

Generate all four. Read `docs/PRODUCT.md` and `docs/HIGHLIGHTS.md` first.
Every claim must be traceable to HIGHLIGHTS.md or PRODUCT.md — no invented proof points.
Overwrite if file already exists.

### docs/SALES-PLAY.md

Battlecard for account executives and sales engineers.

Sections:
- **ICP Snapshot** — who we sell to (from PRODUCT.md), 3 bullets
- **Opening Lines** — one killer opener per vertical defined in PRODUCT.md
- **Discovery Questions** — 5–7 high-value questions based on product pain points
- **Value Props by Role** — 3 bullets per major role, grounded in HIGHLIGHTS.md observations
- **Objection Handling** — from simulation persona objections across cycles
- **Competitive Positioning** — how we win vs. competitors named in PRODUCT.md (factual only)
- **Demo Sequence** — from docs/DEMO-SEQUENCE.md or HIGHLIGHTS.md, ordered by what resonated
- **Proof Points** — specific wow moments from HIGHLIGHTS.md (quote persona voice)
- **Known Gaps** — honest list of open arch issues and carry bugs

### docs/PRODUCT-BROCHURE.md

Customer-facing capability overview. Benefit-led, no jargon.

Sections:
- **The Problem** — 1 paragraph in customer language, drawn from HIGHLIGHTS.md persona feedback
- **Who It's For** — role tier descriptions, what each gets from the product
- **Core Capabilities** — 4–6 capability groups with 3–5 benefit bullets each (from PRODUCT.md modules)
- **How Customers Get Started** — onboarding overview, no professional services required

### docs/PRODUCT-DOCS.md

Technical reference for evaluators.

Sections:
- **Architecture Overview** — stack, auth, data model, tenant isolation (from PRODUCT.md)
- **User Roles Reference** — table: Role | Tier | Primary Function | Key Modules
- **Module Reference** — one section per major module detected in codebase/PRODUCT.md
- **API & Integration** — webhooks, API keys, event types (if applicable)
- **Security & Compliance** — isolation, audit log, RBAC, impersonation (if applicable)
- **Configuration** — platform settings, tenant settings, environment

### docs/RELEASE-NOTES.md

Factual changelog.

Sections:
- **What's New** — features from closed `[Arch]` issues since last tag (from `gh issue list`)
- **Improvements** — UX/content improvements from closed `bug` issues
- **Bug Fixes** — from closed `bug,sim` issues: `[Severity] [module]: [description]`
- **Known Issues** — open carry bugs + open arch issues (transparent)

---

## Phase 3 — Create GitHub Release

```bash
git checkout develop
git pull origin develop
git tag -a [version] -m "Release [version]"
git push origin [version]

gh release create [version] \
  --title "v[version]" \
  --notes-file docs/RELEASE-NOTES.md \
  --target develop
```

If `--dry-run`: print what would be created, skip.

---

## Phase 4 — Merge to Main

```bash
git checkout main
git pull origin main
git merge develop --no-ff -m "Release [version]"
git push origin main
git checkout develop
```

If `--dry-run`: print what would happen, skip.

---

## Phase 5 — Label open issues with version milestone

```bash
gh issue list --label "arch" --state open --limit 50 --json number --jq '.[].number' | \
  xargs -I{} gh issue edit {} --add-label "v1.0" 2>/dev/null || true
```

---

## Phase 6 — Summary

```
/launch COMPLETE
════════════════════════════════════════════════════════
Version:       [version]
Release date:  [date]
GitHub release: [URL]

Artifacts written:
  docs/SALES-PLAY.md
  docs/PRODUCT-BROCHURE.md
  docs/PRODUCT-DOCS.md
  docs/RELEASE-NOTES.md

develop → main: merged
Tag [version]: pushed

[If --dry-run: DRY RUN — no release created, no merge performed.]
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Gates first** — Gate 1 failure (open critical/high bugs) always blocks, no exceptions
2. **Grounded artifacts** — every claim traceable to HIGHLIGHTS.md or PRODUCT.md
3. **Consistent version** — determined once in Phase 1, used everywhere
4. **Dry-run is safe** — never touches git history or creates releases
5. **Honest release notes** — include known issues; never omit carry bugs or open arch issues
6. **main is production** — merging to main is the last step, not the first
7. **Read before writing** — read HIGHLIGHTS.md and PRODUCT.md before any artifact
