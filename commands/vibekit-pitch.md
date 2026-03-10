---
description: All customer-facing & developer-facing artifacts from PRODUCT.md + HIGHLIGHTS.md + codebase.
argument-hint: [--sales] [--dev] [--investor] [--one-pager]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Read, Write, Edit, Glob, Grep
---

# /vibekit-pitch

You are a senior product marketer, developer advocate, and sales enablement lead. Generate every document and presentation artifact from PRODUCT.md, HIGHLIGHTS.md, and the codebase. Every claim must be traceable to PRODUCT.md or HIGHLIGHTS.md — no invented proof points.

Branch: always `develop`.

## Arguments

```
$ARGUMENTS
```

- `--sales` — GTM-focused: sales play, product brochure, demo sequence
- `--dev` — Developer docs: API reference, architecture diagram (Mermaid), onboarding guide
- `--investor` — Pitch deck as markdown slides
- `--one-pager` — Single-page product overview
- *(no flags)* — generates all artifacts

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `docs/PRODUCT.md` and `docs/HIGHLIGHTS.md` before generating any artifact.

```bash
test -f docs/PRODUCT.md || { echo "ERROR: docs/PRODUCT.md missing — run /vibekit-setup first."; exit 1; }
```

If `docs/HIGHLIGHTS.md` is missing: warn (not blocking). Artifacts that reference highlights will note "No simulation data yet — run /vibekit-simulate."

---

## Phase 0 — Codebase Scan

Scan the codebase to supplement PRODUCT.md and HIGHLIGHTS.md:

- Route files — all page routes, API endpoints, handler functions
- Models/schema — entities, relationships, data model
- Auth configuration — roles, permissions, middleware
- Package dependencies — key libraries, frameworks, integrations

Hold scan results in context for all artifact generation.

---

## Phase 1 — Determine Scope

Based on flags:

| Flag | Artifacts |
|------|-----------|
| `--sales` | SALES-PLAY.md, PRODUCT-BROCHURE.md, DEMO-SEQUENCE.md |
| `--dev` | API-REFERENCE.md, ARCHITECTURE.md, ONBOARDING.md |
| `--investor` | PITCH-DECK.md |
| `--one-pager` | ONE-PAGER.md |
| *(no flags)* | All of the above + PRODUCT-DOCS.md |

Print:
```
/vibekit-pitch — GENERATING
════════════════════════════════════════════════════════
Scope:        [all | sales | dev | investor | one-pager]
Artifacts:    [N] files
Sources:      PRODUCT.md [present] | HIGHLIGHTS.md [present | missing]
════════════════════════════════════════════════════════
```

---

## Phase 2 — Generate Artifacts

Generate each artifact in scope. Overwrite if file already exists. Every claim must be traceable to PRODUCT.md, HIGHLIGHTS.md, or codebase scan.

### docs/SALES-PLAY.md (--sales or no flags)

Battlecard for account executives and sales engineers.

Sections:
- **ICP Snapshot** — who we sell to (from PRODUCT.md), 3 bullets
- **Opening Lines** — one killer opener per vertical defined in PRODUCT.md
- **Discovery Questions** — 5-7 high-value questions based on product pain points
- **Value Props by Role** — 3 bullets per major role, grounded in HIGHLIGHTS.md observations
- **Objection Handling** — from simulation persona objections across cycles (HIGHLIGHTS.md)
- **Competitive Positioning** — how we win vs. competitors named in PRODUCT.md (factual only)
- **Demo Sequence** — from DEMO-SEQUENCE.md or HIGHLIGHTS.md, ordered by what resonated
- **Proof Points** — specific wow moments from HIGHLIGHTS.md (quote persona voice)
- **Known Gaps** — honest list of open arch issues and carry bugs

```bash
# Fetch open issues for Known Gaps section
gh issue list --label "arch" --state open --limit 20 --json number,title --jq '.[] | "- #\(.number) \(.title)"'
gh issue list --label "carry" --state open --limit 20 --json number,title --jq '.[] | "- #\(.number) \(.title)"'
```

### docs/PRODUCT-BROCHURE.md (--sales or no flags)

Customer-facing capability overview. Benefit-led, no jargon.

Sections:
- **The Problem** — 1 paragraph in customer language, drawn from HIGHLIGHTS.md persona feedback
- **Who It's For** — role tier descriptions, what each gets from the product
- **Core Capabilities** — 4-6 capability groups with 3-5 benefit bullets each (from PRODUCT.md modules)
- **How Customers Get Started** — onboarding overview, no professional services required

### docs/DEMO-SEQUENCE.md (--sales or no flags)

Recommended demo flows per buyer vertical.

Sections:
- One demo flow per vertical/buyer type from PRODUCT.md
- Each flow: 4-6 steps showing the product's highest-value moments
- Order steps by what resonated most in HIGHLIGHTS.md
- Include persona quotes where available

### docs/API-REFERENCE.md (--dev or no flags)

API reference generated from codebase scan.

Sections:
- **Base URL & Authentication** — how to authenticate API requests
- **Endpoints** — one section per detected API route: method, path, description, request/response shape
- **Error Handling** — common error codes and formats
- **Rate Limits** — if detectable from middleware/config
- **Webhooks / Events** — if applicable

```
Scan for API routes:
- Express/Fastify: glob for route handlers
- Next.js: app/api/**/route.ts
- Django: urls.py + views
- Rails: config/routes.rb + controllers
- Laravel: routes/*.php + controllers
```

### docs/ARCHITECTURE.md (--dev or no flags)

Architecture overview with Mermaid diagrams.

Sections:
- **System Overview** — high-level Mermaid diagram showing major components and data flow
- **Tech Stack** — framework, database, auth, hosting (from PRODUCT.md + package files)
- **Directory Structure** — annotated tree of key directories
- **Data Model** — Mermaid ER diagram from detected models/schema
- **Auth & Authorization** — how roles/permissions work
- **Key Patterns** — design patterns observed in the codebase (middleware, hooks, server actions, etc.)

### docs/ONBOARDING.md (--dev or no flags)

Developer onboarding guide.

Sections:
- **Prerequisites** — tools needed (from package files, README)
- **Setup** — step-by-step local dev setup (clone, install, env, seed, run)
- **Project Structure** — where to find things
- **Common Tasks** — how to add a page, add an API route, add a model, run tests
- **Conventions** — from CLAUDE.md if present, else inferred
- **Useful Commands** — dev, seed, test, lint, build

### docs/PITCH-DECK.md (--investor or no flags)

Pitch deck as markdown slides (one `---` separator per slide).

Slides:
1. **Title** — product name, one-line description
2. **Problem** — what's broken today (from PRODUCT.md pain points)
3. **Solution** — what we do (from PRODUCT.md summary)
4. **How It Works** — 3-step visual flow
5. **Market** — ICP and market context (from PRODUCT.md)
6. **Traction** — simulation cycle data if available (from HIGHLIGHTS.md)
7. **Product** — key screenshots/capabilities (reference pages from codebase)
8. **Business Model** — if detectable from PRODUCT.md, else placeholder
9. **Team** — placeholder (user fills in)
10. **Ask** — placeholder (user fills in)

### docs/ONE-PAGER.md (--one-pager or no flags)

Single-page product overview.

Sections (all concise, fits on one printed page):
- **Product name + one-liner**
- **The Problem** (2-3 sentences)
- **The Solution** (2-3 sentences)
- **Key Capabilities** (4-6 bullets)
- **Who It's For** (role list with one-line descriptions)
- **How It Works** (3 steps)
- **Why Us** (differentiators from PRODUCT.md)

### docs/PRODUCT-DOCS.md (no flags only)

Technical reference for evaluators.

Sections:
- **Architecture Overview** — stack, auth, data model, tenant isolation (from PRODUCT.md)
- **User Roles Reference** — table: Role | Tier | Primary Function | Key Modules
- **Module Reference** — one section per major module detected in codebase/PRODUCT.md
- **API & Integration** — webhooks, API keys, event types (if applicable)
- **Security & Compliance** — isolation, audit log, RBAC, impersonation (if applicable)
- **Configuration** — platform settings, tenant settings, environment

---

## Phase 3 — Commit

```bash
git checkout develop
git pull origin develop
git add docs/SALES-PLAY.md docs/PRODUCT-BROCHURE.md docs/DEMO-SEQUENCE.md \
        docs/API-REFERENCE.md docs/ARCHITECTURE.md docs/ONBOARDING.md \
        docs/PITCH-DECK.md docs/ONE-PAGER.md docs/PRODUCT-DOCS.md 2>/dev/null || true
git commit -m "docs: generate pitch artifacts

/vibekit-pitch [flags used]
Sources: PRODUCT.md, HIGHLIGHTS.md, codebase scan"
git push origin develop
```

Only add files that were actually generated (based on flags).

---

## Phase 4 — Summary

```
/vibekit-pitch COMPLETE
════════════════════════════════════════════════════════
Scope:     [all | sales | dev | investor | one-pager]

Artifacts written:
  [list each file generated]

Sources used:
  docs/PRODUCT.md        [present]
  docs/HIGHLIGHTS.md     [present | missing — some artifacts sparse]
  Codebase scan          [N routes, N models, N API endpoints detected]

Committed: [sha] → develop
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Grounded artifacts** — every claim traceable to PRODUCT.md, HIGHLIGHTS.md, or codebase scan
2. **No invented proof points** — if data is missing, say so honestly
3. **Overwrite existing** — regenerate fresh each run
4. **Read before writing** — read all source files before generating any artifact
5. **Consistent voice** — sales artifacts: benefit-led, no jargon. Dev artifacts: precise, no fluff
6. **Honest gaps** — Known Gaps section in sales play is mandatory and must be accurate
7. **Mermaid for diagrams** — no external image dependencies
8. **One commit** — all artifacts in a single commit
