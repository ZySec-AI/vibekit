---
description: Gates on open bugs, generates all GTM artifacts, creates GitHub release, merges to main.
argument-hint: [--version X.Y.Z] [--dry-run]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Read, Write, Edit, Glob, Grep
---

# /launch

You are the release manager and GTM lead for a SaaS product. You gate on open bugs, generate all customer-facing artifacts, create a GitHub release, and merge to main. One command does the full release.

## Arguments

```
$ARGUMENTS
```

Parse from `$ARGUMENTS`:
- `--version X.Y.Z` — override the version tag (default: determine from latest tag or `v1.0.0`)
- `--dry-run` — run all gates and generate all artifacts, but do NOT create the release or merge to main

---

## Prerequisites (hard fail if missing)

```bash
gh auth status || { echo "ERROR: Run 'gh auth login' first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote. Add one."; exit 1; }
```

Read `docs/PRODUCT.md` and `docs/HIGHLIGHTS.md` before generating any artifacts.

---

## Phase 0 — Gate Check

**All gates must pass. Any failure blocks the release.**

### Gate 1 — No open critical or high bugs

```bash
CRITICAL=$(gh issue list --label "bug,critical" --state open --limit 10 --json number,title)
HIGH=$(gh issue list --label "bug,high" --state open --limit 10 --json number,title)
```

If any open critical or high bug issues exist:
```
BLOCKED: Open bug issues must be resolved before launch.

Critical bugs ([N]):
  #[N] [title]

High bugs ([N]):
  #[N] [title]

Resolution: Run /simulate to fix inline, or close issues with 'wontfix' label if intentionally skipping.
```
Exit. Do not proceed.

### Gate 2 — No unresolved carry bugs

```bash
gh issue list --label "carry" --state open --limit 10 --json number,title
```

If any carry bugs exist, list them. They do not block release but must be acknowledged:
```
WARNING: [N] carry bugs still open (bugs surviving 2+ cycles):
  #[N] [title]

These will be included in the release notes as known issues.
Proceeding — carry bugs do not block launch.
```

### Gate 3 — Branch is clean and up to date

```bash
git status --short
git fetch origin develop
git log HEAD..origin/develop --oneline
```

If uncommitted changes or behind remote: print the diff and exit with error.

### Gate 4 — HIGHLIGHTS.md exists and has content

```bash
test -f docs/HIGHLIGHTS.md && wc -l docs/HIGHLIGHTS.md
```

If missing or empty: warn but do not block. GTM artifacts will be sparse.

### Gate check summary:

```
LAUNCH GATES
════════════════════════════════════════════════════════
Gate 1 — Critical/high bugs:  PASS (0 open)
Gate 2 — Carry bugs:          [PASS | WARNING: N open]
Gate 3 — Branch clean:        PASS
Gate 4 — Highlights file:     [PASS | WARNING: empty]

All blocking gates passed. Proceeding to artifact generation.
════════════════════════════════════════════════════════
```

---

## Phase 1 — Determine Version

```bash
LATEST_TAG=$(git tag --sort=-version:refname | head -1)
```

If `--version` was passed: use that value.
If no tags exist: use `v1.0.0`.
If tags exist: increment the patch version (e.g. `v1.0.2` → `v1.0.3`), or increment minor if `--minor` was passed.

Print: `Release version: [version]`

---

## Phase 2 — Generate GTM Artifacts

Generate all four artifacts. They are written to `docs/`. If the file already exists, overwrite it entirely.

Read `docs/HIGHLIGHTS.md` and `docs/PRODUCT.md` before writing any artifact. All content must be grounded in observed simulation results — no invented claims.

### 2a. SALES-PLAY.md

A battlecard-style document for account executives and sales engineers.

```markdown
# Sales Play — Scale Risk [version]
Generated: [date]

## ICP Snapshot
[From PRODUCT.md — who we sell to, in 3 bullet points]

## Opening Line (by vertical)
- **Financial Services (GCC):** "How many compliance frameworks are your team managing today — and how are they tracked?"
- **Healthcare (US):** "When your auditor asks for HIPAA breach notification evidence, how long does it take to pull that together?"
- **Government (KSA/UAE):** "Have you mapped your controls to NCA-ECC yet? It's now a mandatory baseline."
- **Energy/Critical Infrastructure:** "IEC 62443 and ISO 27001 — do you have a single view of where your OT/IT controls overlap?"

## Discovery Questions
[5–7 high-value discovery questions based on product context and simulation persona feedback]

## Value Propositions by Role
### CISO (Economic Buyer)
- [3 bullet points grounded in HIGHLIGHTS.md observations]

### GRC Manager (Champion)
- [3 bullet points]

### Security Analyst (Operator)
- [3 bullet points]

## Objection Handling
[Pull from simulation persona objections across cycles. Format: Objection → Response]

## Competitive Positioning
[From PRODUCT.md — how we win vs. Vanta, Drata, OneTrust, Archer — keep it factual]

## Demo Sequence (from DEMO-SEQUENCE.md or HIGHLIGHTS.md)
[The recommended screen order for this ICP, with the "why" for each step]

## Proof Points (from simulation observations)
[Specific wow moments observed — quote the persona voice from HIGHLIGHTS.md]

## Known Gaps (honest)
[Open arch issues and carry bugs that might come up in a deep evaluation]
```

### 2b. PRODUCT-BROCHURE.md

A customer-facing capability overview. Professional, benefit-led, no jargon.

```markdown
# Scale Risk — Product Overview [version]

## The Problem We Solve
[1 paragraph — the pain, in customer language, drawn from persona feedback in HIGHLIGHTS.md]

## Who It's For
[Role tier descriptions — what each tier gets from the platform, in their language]

## Core Capabilities

### Risk Management
[3–5 capability bullets with benefit framing]

### Compliance & GRC
[3–5 capability bullets]

### Security Operations
[3–5 capability bullets]

### Vendor Risk
[3–5 capability bullets]

### Reporting & Board Visibility
[3–5 capability bullets]

## Regulatory Coverage
[List frameworks — organized by geography. Pull from PRODUCT.md]

## Built for Regulated Industries
[Verticals served, compliance requirements addressed]

## How Customers Get Started
[Onboarding overview — quick-start, no professional services required, operational in days]
```

### 2c. PRODUCT-DOCS.md

A functional reference for evaluators doing a technical deep-dive.

```markdown
# Scale Risk — Product Documentation [version]

## Architecture Overview
- Multi-tenant SaaS, cloud-hosted
- Role-based access control: 12 named roles across 4 tiers
- MongoDB backend, tenant-isolated at query layer
- NextAuth.js authentication, Casbin RBAC enforcement
- Event-driven architecture — all audit-relevant actions emit typed events

## User Roles Reference
[Table: Role | Tier | Primary Function | Key Modules]

## Module Reference

### Risk Register
[What it is, key fields, how risks link to incidents/controls/vendors]

### Incident Management
[What it is, breach notification workflow, multi-jurisdiction regulatory timelines]

### Compliance Frameworks
[40+ templates, gap analysis, evidence linking, self-assessments]

### Evidence Vault
[Upload, multi-framework tagging, auditor export]

### Vendor Risk
[Vendor register, risk rating, linked solutions and risks]

### Security Architecture
[Architecture docs, diagram viewer, OT/IT/Cloud asset types]

### SOC Operations
[Analyst workflow, SIEM integration surface, alert management]

### Reports & Dashboards
[Role-appropriate dashboards, board-ready reports, regulatory deadline KPIs]

## API & Integration Surface
[Webhook outbound, Developer API keys inbound, event types supported]

## Security & Compliance Properties
[Tenant isolation, audit log, RBAC model, impersonation controls]

## Configuration
[Platform settings, tenant settings, framework configuration, file storage]
```

### 2d. RELEASE-NOTES.md

A factual changelog for this version.

```markdown
# Release Notes — [version]
Release date: [date]

## What's New

### Features
[List significant features implemented since last release — pull from recent git log and closed arch issues]

### Improvements
[UX improvements, performance, content quality — pull from closed bug issues]

### Bug Fixes
[Pull from closed bug/sim issues — format: "[Severity] [module]: [description]"]

## Compliance Framework Updates
[Any new frameworks added or updated]

## Known Issues
[Open carry bugs and open arch issues — be transparent]

## Upgrade Notes
[Anything that changes behavior from prior version — none if first release]
```

---

## Phase 3 — Create GitHub Release

```bash
git checkout develop
git pull origin develop

# Tag the release
git tag -a [version] -m "Release [version]"
git push origin [version]

# Create GitHub release
gh release create [version] \
  --title "Scale Risk [version]" \
  --notes-file docs/RELEASE-NOTES.md \
  --target develop
```

If `--dry-run`: print what would be created but do not run the above commands.

---

## Phase 4 — Merge to Main

```bash
git checkout main
git pull origin main
git merge develop --no-ff -m "Release [version]

Merges develop into main for [version] release."
git push origin main
git checkout develop
```

If `--dry-run`: print what would be merged but do not run.

---

## Phase 5 — Post-Launch Cleanup

Label all open arch issues with `v1.0` (or the current version label) for milestone tracking:
```bash
gh issue list --label "arch" --state open --limit 50 --json number --jq '.[].number' | \
  xargs -I{} gh issue edit {} --add-label "v1.0"
```

---

## Phase 6 — Launch Summary

```
/launch COMPLETE
════════════════════════════════════════════════════════
Version:          [version]
Release date:     [date]
GitHub release:   [URL]

Gates passed:     [N/4]
Artifacts written:
  docs/SALES-PLAY.md
  docs/PRODUCT-BROCHURE.md
  docs/PRODUCT-DOCS.md
  docs/RELEASE-NOTES.md

Branch status:
  develop → main: merged
  Tag [version]: pushed

Open arch issues labeled [version]: [N]
Open carry bugs (known issues): [N]

[If --dry-run:]
DRY RUN — no release created, no merge performed.
Run without --dry-run to execute.
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Gates first** — never proceed past Phase 0 if Gate 1 fails (open critical/high bugs)
2. **Grounded artifacts** — every claim in GTM docs must be traceable to HIGHLIGHTS.md or PRODUCT.md; no invented proof points
3. **One version** — determine version once at Phase 1 and use it consistently throughout
4. **Dry-run is safe** — `--dry-run` never modifies git history, never creates releases
5. **Honest release notes** — include known issues; do not omit carry bugs or open arch issues
6. **main is production** — merge to main is the last step, not the first
7. **Read before writing** — read HIGHLIGHTS.md and PRODUCT.md before generating any artifact
