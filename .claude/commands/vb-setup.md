---
description: Bootstrap a project for the /vb-simulate → /vb-build → /vb-launch workflow. Run once per project.
argument-hint: [--auto] [--refresh]
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Bash(brew:*), Bash(curl:*), Bash(chmod:*), Read, Write, Edit, Glob, Grep
---

# /vb-setup

Bootstrap this project for the vibekit development loop. Run once when starting on a new project.

## Arguments

```
$ARGUMENTS
```

- `--auto` — generate PRODUCT.md entirely from codebase scan, zero questions. Marks uncertain sections with `[INFERRED]`.
- `--refresh` — re-scan codebase, diff against existing PRODUCT.md, propose updates for stale sections.

---

## Step 1 — Prerequisites check

```bash
claude --version    2>/dev/null || echo "MISSING: npm install -g @anthropic-ai/claude-code"
gh --version        2>/dev/null || echo "MISSING: https://cli.github.com — brew install gh (mac) / sudo apt install gh (linux)"
gh auth status      2>/dev/null || echo "NOT AUTHENTICATED: gh auth login"
git remote get-url origin 2>/dev/null || echo "NO REMOTE: git remote add origin <url>"
```

Detect package manager:
```bash
if   [ -f "pnpm-lock.yaml" ] || [ -f "package.json" ]; then PM="pnpm"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then PM="uv"
else PM="unknown"; fi
```

Node projects use **pnpm**. Python projects use **uv**. No other package managers are supported.

Check Playwright:
```bash
npx playwright --version 2>/dev/null || PLAYWRIGHT_MISSING=true
```

If missing, install:
```bash
if [ "$PLAYWRIGHT_MISSING" = "true" ]; then
  echo "Installing Playwright..."
  npx playwright install chromium --with-deps
fi
```

Playwright is required for `/vb-simulate`, `/vb-build`, and `/vb-review`. All browser automation runs via `npx playwright` — no MCP server needed.

Print status table:
```
PREREQUISITE CHECK
══════════════════════════════════════
Claude Code:      [OK vX.X.X | MISSING]
gh CLI:           [OK vX.X.X | MISSING]
gh auth:          [OK (@user) | NOT AUTHENTICATED]
git remote:       [OK (url)   | MISSING]
Package manager:  [pnpm | uv | unknown]
Playwright:       [OK vX.X.X | installed now]
══════════════════════════════════════
```

If any required prerequisite is missing: print install command and exit. Do not proceed.

---

## Step 2 — PRODUCT.md (Detect-Draft-Confirm)

```bash
test -f docs/PRODUCT.md && echo "exists" || echo "missing"
```

### If `--refresh` flag and PRODUCT.md exists:
Read existing `docs/PRODUCT.md`. Run Phase A (codebase scan) below. Compare scan results against PRODUCT.md sections. For each section where the codebase has diverged (new routes, new roles, changed tech stack, new dependencies), show a diff:
```
PRODUCT.md REFRESH
══════════════════════════════════════════════════
Section: Current Product State
  - Tech stack: was "Next.js 13" → now "Next.js 14" (from package.json)
  - New routes found: /admin/audit-log, /settings/billing
  - New dependency: @stripe/stripe-js (suggests billing integration)

Section: User Roles
  - New role detected: "Billing Admin" (from routes + auth config)

Apply these updates? (yes / or tell me what to change)
══════════════════════════════════════════════════
```
Apply on approval. Max 2 revision rounds, then write and tell user to edit directly.
After PRODUCT.md refresh, skip to Step 3.

### If PRODUCT.md already exists (no --refresh):
Read it, print "PRODUCT.md already exists — skipping. Use --refresh to update." and continue to Step 2.25.

### If PRODUCT.md is missing (or --auto flag):

#### Phase A — Deep Codebase Scan (zero input)

Before asking anything, scan and extract from:
- `CLAUDE.md`, `README.md` — product description, features, audience
- `package.json` / `pyproject.toml` / `Gemfile` — name, description, dependencies (infer tech stack, auth lib, DB, UI framework)
- Route files (`routes.ts`, `App.tsx`, `urls.py`, etc.) — infer roles, pages, modules
- `.env.example` — service integrations
- Navigation components — menu items, role-based access
- DB schema / models — entities, relationships, multi-tenancy

Detect if this is a **greenfield project** (minimal code): fewer than 5 source files, no route files, no models/schema.

Print what was found:
```
CODEBASE SCAN
══════════════════════════════════════════════════
  Tech stack:     [e.g. Next.js 14 + TypeScript, Prisma + PostgreSQL]
  Auth:           [e.g. NextAuth (Google + credentials)]
  Dev server:     [e.g. pnpm dev (port 3000) | uv run uvicorn main:app (port 8000)]
  Seed command:   [e.g. pnpm seed | uv run python manage.py seed]
  Routes found:   [e.g. /dashboard, /settings, /reports, /admin/users]
  Likely roles:   [e.g. Admin, User (from routes + auth config)]
  Modules:        [e.g. Dashboard, Reports, Settings, User Management]
══════════════════════════════════════════════════
```

If greenfield (almost nothing found), adjust the scan output:
```
CODEBASE SCAN
══════════════════════════════════════════════════
  This looks like a new project — not much code to scan yet.
  Tech stack:     [whatever detected, or "not yet determined"]
══════════════════════════════════════════════════
```

#### Phase B — Single Freeform Prompt (one interaction)

**If `--auto` flag:** skip Phase B entirely. Proceed to Phase C using only scan data.

**If greenfield project:**
```
This looks like a new project — not much code to scan yet.
Tell me: what are you building, who is it for, and what pain points does it solve?

(One paragraph is fine. Include roles if you know them already.)
```

**Otherwise (normal project with code):**
```
Tell me about your product — I'll combine this with what I found in the code:

  - What does it do and who is it for?
  - What pain points does it solve?
  - Who are the competitors?
  - Anything wrong in the scan above?

(One paragraph is fine. Skip anything I already got right.)
```

Wait for answer.

#### Phase C — Draft & Confirm (one interaction)

Generate complete `docs/PRODUCT.md` combining scan results + user input (or scan-only for `--auto`).

For `--auto` mode: mark any section that required guessing with `[INFERRED]` — e.g. `[INFERRED] Industries: B2B SaaS (based on tech stack and dependencies)`.

```markdown
# PRODUCT.md — [Product Name]

## Product Summary
[1–2 sentence description]

## Ideal Customer Profile (ICP)
- **Buyer**: [inferred from code + user input]
- **End users**: [all named roles]
- **Industries**: [from user input or inferred]
- **Company profile**: [infer from context — size, compliance requirements, etc.]

## User Roles
| Role | Tier | What they do |
|------|------|-------------|
[One row per role. Infer tier (Leadership/Manager/Operator/Admin) from role names and codebase.]

## Primary Tasks per Role
[For each role: list 3–5 most frequent actions they perform in the product.
Infer from codebase route structure + user answers. This drives /vb-simulate click-count gates.]

## Pain Points Solved
[Bullet list, customer-voice language]

## Key Differentiators
[Bullet list. Skip section if unknown.]

## Competitive Context
| Competitor / Alternative | How we win |
|--------------------------|-----------|
[Skip section if unknown.]

## Current Product State
- **Status**: [from user input or inferred]
- **Tech stack**: [detected from codebase — framework, DB, language]
- **Dev server**: [detected — e.g. `pnpm dev` (Node) | `uv run uvicorn main:app` (Python)]
- **Seed command**: [detected — e.g. `pnpm seed` (Node) | `uv run python manage.py seed` (Python)]
- **Auth**: [detected — e.g. NextAuth, Django auth, Supabase]

## Demo Sequences
[Generate 2–3 recommended demo flows for the buyer persona.
Each flow: 4–6 steps showing the product's highest-value moments.]
```

Show the draft, then ask:
```
Approve this? (yes / or tell me what to change)
```

Write on approval. Max 2 revision rounds, then write and tell user to edit directly.

Print: "PRODUCT.md written to docs/PRODUCT.md — review and edit any time. All vibekit commands re-read it on every run."

This file is the single source of truth for all vibekit commands. Keep it updated as the product evolves.

---

## Step 2.25 — CLAUDE.md generation

```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
```

**If CLAUDE.md already exists:** skip this step.

**If missing:** generate one from codebase analysis:

Scan:
- Project directory layout (auto-detect with `ls` and glob)
- Coding conventions (indentation, naming, import style — infer from 3-5 code samples)
- Tech stack specifics (framework, ORM, auth, with version numbers from lockfiles)
- Common commands (dev, seed, test, lint — from package.json scripts for Node / pyproject.toml for Python)

Generate `CLAUDE.md`:

```markdown
# CLAUDE.md

## Project Structure
[auto-detected directory layout — top-level dirs with one-line purpose each]

## Tech Stack
[framework, ORM, auth, UI library — with version numbers from lockfiles]

## Common Commands
[make dev, make seed, make clean — from Makefile]
[pnpm test / uv run pytest — from package.json or pyproject.toml]

## Coding Conventions
[indentation, naming style, import conventions — inferred from code samples]

## Notes
- This project uses vibekit. See docs/PRODUCT.md for product context.
```

Show draft, ask:
```
CLAUDE.md generated. Approve? (yes / no / or tell me what to change)
```

Write on approval. Skip if user declines.

---

## Step 2.5 — Makefile generation

```bash
test -f Makefile && echo "exists" || echo "missing"
```

**If Makefile already exists:** skip this step.

**If missing:** generate one from codebase analysis:

Scan:
- Stack type: Node (package.json present) → use **pnpm**. Python (pyproject.toml / requirements.txt) → use **uv**.
- Database type (infer from dependencies — prisma datasource, pg, asyncpg, motor, redis, etc.)
- `docker-compose.yml` / `compose.yaml` presence (confirms `run` target will work)
- Dev/seed scripts: `package.json` scripts for Node, `pyproject.toml` [tool.uv.scripts] or `Makefile` for Python

Generate a `Makefile` with exactly four targets:

```makefile
# ─── Config ──────────────────────────────────────────────────────────────────
APP_NAME   ?= [detected from package.json name or directory name]
DB_NAME    ?= $(APP_NAME)_dev
DB_PORT    ?= [detected: 5432 postgres | 27017 mongo | 3306 mysql | 6379 redis]
DB_IMAGE   ?= [detected: postgres:16 | mongo:7 | mysql:8 | redis:7]

# Node projects → pnpm. Python projects → uv.
PM := [pnpm | uv run]

# ─── Targets ─────────────────────────────────────────────────────────────────

.PHONY: dev run seed clean help

## dev — Run app locally (hot-reload). Start DBs in Docker if not running.
dev:
	@docker ps --format '{{.Ports}}' | grep -q "$(DB_PORT)" || \
	  (docker run -d --name $(APP_NAME)-db -p $(DB_PORT):$(DB_PORT) $(DB_IMAGE) && sleep 2)
	$(PM) dev          # Node: pnpm dev | Python: uv run [entrypoint]

## run — Start everything in Docker (app + all DBs).
run:
	docker compose up --build

## seed — Load dev accounts and fixture data.
seed:
	$(PM) seed         # Node: pnpm seed | Python: uv run seed (or uv run python manage.py seed)

## clean — Stop all containers, remove volumes, wipe all data (destructive).
clean:
	@printf "Press Enter to continue, Ctrl+C to cancel: " && read _
	docker compose down -v --remove-orphans
	docker rm -f $(APP_NAME)-db 2>/dev/null || true
	docker volume ls -q | grep $(APP_NAME) | xargs docker volume rm 2>/dev/null || true

## help — List available targets.
help:
	@grep -E '^## ' Makefile | sed 's/## //'
```

Adapt commands to detected stack:
- **Node/pnpm**: `PM=pnpm`, dev script from `package.json`, seed from `package.json` scripts
- **Python/uv**: `PM=uv run`, dev entrypoint from `pyproject.toml`, seed from `pyproject.toml` scripts or `manage.py`
- Adapt DB startup env vars to DB type (`POSTGRES_DB`/`POSTGRES_PASSWORD` for postgres, `MONGO_INITDB_DATABASE` for mongo)

Show draft, then ask:
```
Makefile generated. Approve? (yes / no / or tell me what to change)
```

Write on approval. Skip if user declines.

Print: `Makefile written — run 'make help' to see available targets.`

---

## Step 2.75 — Dev mode + quick login

vibekit's `/vb-simulate` and `/vb-build` need to authenticate as different user roles via Playwright. This step ensures reliable, automated login for all browser automation.

### 2.75a — DEV_MODE env var

Check for `.env` or `.env.local`:
```bash
ENV_FILE=""
if   [ -f ".env.local" ]; then ENV_FILE=".env.local"
elif [ -f ".env" ];       then ENV_FILE=".env"
fi
```

**If env file exists:** check if `DEV_MODE` is already set:
```bash
grep -q "DEV_MODE" "$ENV_FILE" 2>/dev/null && echo "DEV_MODE already set" || echo "DEV_MODE=true" >> "$ENV_FILE"
```

**If no env file exists:** create `.env.local` (gitignored by default in most frameworks):
```bash
echo "DEV_MODE=true" > .env.local
```

Ensure `.env.local` is in `.gitignore`:
```bash
grep -q ".env.local" .gitignore 2>/dev/null || echo ".env.local" >> .gitignore
```

### 2.75b — Dev login route

Scan the codebase to determine the auth stack and whether a dev login mechanism already exists:

```bash
# Check for existing dev login
grep -rlE '(dev-login|dev_login|bypass|quick.?login|__dev)' --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.rb" . 2>/dev/null | head -5
```

**If dev login already exists:** print `Dev login: detected at [path] — skipping.` and move on.

**If no dev login exists:** scaffold one based on the detected framework.

Scan the project to detect the auth stack:
- **NextAuth / Auth.js** — look for `next-auth`, `@auth/core` in dependencies, `auth.ts` / `[...nextauth]` route
- **Supabase Auth** — look for `@supabase/supabase-js`, `@supabase/auth-helpers`
- **Django** — look for `django.contrib.auth`, `LOGIN_URL` in settings
- **Rails / Devise** — look for `devise` in Gemfile
- **Custom JWT** — look for `jsonwebtoken`, `jose`, `PyJWT` in dependencies
- **No auth** — no auth dependencies found

**Scaffold a dev login route gated behind `DEV_MODE=true`:**

For **Next.js** (App Router):
Write `src/app/dev-login/page.tsx` (or `app/dev-login/page.tsx` — match existing app dir):
```tsx
// Dev-only login — only active when DEV_MODE=true
// Used by vibekit Playwright automation for role-based testing
import { redirect } from 'next/navigation'

export default function DevLogin({ searchParams }: { searchParams: { role?: string } }) {
  if (process.env.DEV_MODE !== 'true') redirect('/')
  // Role options derived from seed data or PRODUCT.md roles
  // Each button sets the session/cookie for that role and redirects to /
  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Dev Login</h1>
      <p>Select a role to sign in as:</p>
      {/* Render a button per role — roles detected from PRODUCT.md or auth config */}
      {/* Each button calls a server action or API route that creates a session */}
    </div>
  )
}
```

For **Next.js** (Pages Router): Write `pages/dev-login.tsx` with same pattern.

For **Django**: Write a view at `accounts/views.py` and wire to `urlpatterns`:
```python
# Dev-only login — only active when DEV_MODE=true
from django.conf import settings
from django.contrib.auth import login
from django.contrib.auth.models import User
from django.http import HttpResponseRedirect, HttpResponseForbidden

def dev_login(request):
    if not getattr(settings, 'DEV_MODE', False):
        return HttpResponseForbidden()
    role = request.GET.get('role', 'user')
    user = User.objects.filter(is_staff=(role == 'admin')).first()
    if user:
        login(request, user)
    return HttpResponseRedirect('/')
```

For **Rails**: Write a controller action gated behind `ENV['DEV_MODE']`.

For **React SPA (Vite/CRA)**: Write an API endpoint or a dev-only component that sets the auth token in localStorage.

**The scaffolded route must:**
1. Only work when `DEV_MODE=true` (hard gate — returns 403/redirect otherwise)
2. Accept a `role` query parameter (`/dev-login?role=admin`, `/dev-login?role=user`)
3. Create a valid session/token for that role using the app's actual auth mechanism
4. Redirect to `/` after login
5. Include a comment: `// vibekit dev login — remove before production`

**Persist the dev login path for downstream commands:**
```bash
echo "DEV_LOGIN_PATH=/dev-login" >> .vibekit/repo.env
```

### 2.75c — Seed credentials (if no seed data)

Check if seed data exists:
```bash
# Node
grep -q '"seed"' package.json 2>/dev/null && SEED_EXISTS=true
# Python
grep -q 'seed' pyproject.toml 2>/dev/null && SEED_EXISTS=true
# General
ls **/seed*.{ts,js,py,rb} 2>/dev/null && SEED_EXISTS=true
```

**If no seed script exists:** generate minimal seed data with one user per role from `docs/PRODUCT.md`:
- Read roles from PRODUCT.md
- Generate a seed script that creates one user per role with predictable credentials:
  - Email: `{role}@dev.local` (e.g. `admin@dev.local`, `user@dev.local`)
  - Password: `dev123456`
- Write seed script matching the project's ORM/DB pattern
- Add `seed` script to `package.json` scripts (Node) or `pyproject.toml` (Python)

**If seed script already exists:** print `Seed data: detected — skipping.` and move on.

Print:
```
DEV MODE
══════════════════════════════════════
  DEV_MODE:     set in [.env.local | .env]
  Dev login:    [scaffolded at /dev-login | already exists at [path] | skipped (no auth)]
  Seed data:    [created | already exists]
  Credentials:  {role}@dev.local / dev123456
══════════════════════════════════════
```

---

## Step 2.85 — Structured logging (OTel) + error handling (RFC 9457)

Production-ready apps need structured observability and consistent error responses from day one. This step scaffolds both.

### 2.85a — OpenTelemetry structured logging

Detect existing logging setup:
```bash
# Node
grep -rlE '(@opentelemetry|otel|pino|winston|bunyan)' --include="*.ts" --include="*.js" package.json 2>/dev/null | head -3
# Python
grep -rlE '(opentelemetry|structlog|python-json-logger)' --include="*.py" pyproject.toml requirements.txt 2>/dev/null | head -3
```

**If OTel or structured logging already configured:** print `Logging: structured logging detected — skipping.` and move on.

**If no structured logging exists:** scaffold based on the detected stack.

For **Node/pnpm** projects — install and configure `pino` with OTel-compatible format:

```bash
pnpm add pino pino-pretty
```

Write `src/lib/logger.ts` (or match existing project source dir):
```typescript
// Structured logger — OTel-compatible format
// vibekit scaffolded — customize as needed
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level(label) { return { severity: label.toUpperCase() } },
  },
  messageKey: 'message',
  timestamp: () => `,"timestamp":"${new Date().toISOString()}"`,
  // OTel semantic conventions: service.name, service.version
  base: {
    'service.name': process.env.SERVICE_NAME || '[APP_NAME]',
    'service.version': process.env.npm_package_version || '0.0.0',
  },
})

// Request-scoped child logger (attach trace context)
export function requestLogger(traceId?: string, spanId?: string) {
  return logger.child({
    ...(traceId && { 'trace.id': traceId }),
    ...(spanId && { 'span.id': spanId }),
  })
}
```

For **Python/uv** projects — install and configure `structlog` with OTel-compatible format:

```bash
uv add structlog
```

Write `app/logging.py` (or match existing project layout):
```python
"""Structured logger — OTel-compatible format.
vibekit scaffolded — customize as needed.
"""
import os, structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(
        int(os.environ.get("LOG_LEVEL", "20"))  # 20=INFO
    ),
)

def get_logger(**kwargs):
    return structlog.get_logger(
        service_name=os.environ.get("SERVICE_NAME", "[APP_NAME]"),
        **kwargs,
    )
```

### 2.85b — RFC 9457 Problem Details error responses

RFC 9457 defines a standard JSON format for HTTP API error responses. This ensures every error from the app is machine-readable and consistent.

Detect existing error handling:
```bash
# Node
grep -rlE '(problem.details|RFC.?9457|application/problem\+json|ProblemDetail)' --include="*.ts" --include="*.js" . 2>/dev/null | head -3
# Python
grep -rlE '(problem.details|RFC.?9457|application/problem\+json|ProblemDetail)' --include="*.py" . 2>/dev/null | head -3
```

**If RFC 9457 already implemented:** print `Error handling: RFC 9457 detected — skipping.` and move on.

**If not found:** scaffold based on detected stack.

For **Node/pnpm** (Next.js / Express) — write `src/lib/errors.ts`:
```typescript
// RFC 9457 Problem Details — standard error responses
// vibekit scaffolded — customize error codes for your domain
// Spec: https://www.rfc-editor.org/rfc/rfc9457

export interface ProblemDetail {
  type: string           // URI identifying the error type
  title: string          // Short human-readable summary
  status: number         // HTTP status code
  detail?: string        // Human-readable explanation specific to this occurrence
  instance?: string      // URI identifying the specific occurrence
  [key: string]: unknown // Extension members
}

// ── Error codes — add your domain-specific codes here ──
export const ErrorCodes = {
  // Auth
  UNAUTHORIZED:       { type: '/errors/unauthorized',       title: 'Unauthorized',        status: 401 },
  FORBIDDEN:          { type: '/errors/forbidden',          title: 'Forbidden',            status: 403 },
  // Validation
  VALIDATION_ERROR:   { type: '/errors/validation',         title: 'Validation Error',     status: 422 },
  // Resources
  NOT_FOUND:          { type: '/errors/not-found',          title: 'Not Found',            status: 404 },
  CONFLICT:           { type: '/errors/conflict',           title: 'Conflict',             status: 409 },
  // Server
  INTERNAL_ERROR:     { type: '/errors/internal',           title: 'Internal Server Error', status: 500 },
  SERVICE_UNAVAILABLE:{ type: '/errors/service-unavailable',title: 'Service Unavailable',  status: 503 },
} as const

export function problemResponse(
  code: keyof typeof ErrorCodes,
  detail?: string,
  extensions?: Record<string, unknown>
): Response {
  const base = ErrorCodes[code]
  const body: ProblemDetail = {
    ...base,
    ...(detail && { detail }),
    ...extensions,
    instance: undefined, // set per-request if needed
  }
  return new Response(JSON.stringify(body), {
    status: base.status,
    headers: { 'Content-Type': 'application/problem+json' },
  })
}
```

For **Python/uv** (Django / FastAPI) — write `app/errors.py`:
```python
"""RFC 9457 Problem Details — standard error responses.
vibekit scaffolded — customize error codes for your domain.
Spec: https://www.rfc-editor.org/rfc/rfc9457
"""
from dataclasses import dataclass, field, asdict
from typing import Any

@dataclass
class ProblemDetail:
    type: str
    title: str
    status: int
    detail: str | None = None
    instance: str | None = None
    extensions: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict:
        d = {k: v for k, v in asdict(self).items() if v is not None and k != "extensions"}
        d.update(self.extensions)
        return d

# ── Error codes — add your domain-specific codes here ──
ERROR_CODES = {
    "UNAUTHORIZED":        ProblemDetail("/errors/unauthorized",        "Unauthorized",         401),
    "FORBIDDEN":           ProblemDetail("/errors/forbidden",           "Forbidden",            403),
    "VALIDATION_ERROR":    ProblemDetail("/errors/validation",          "Validation Error",     422),
    "NOT_FOUND":           ProblemDetail("/errors/not-found",           "Not Found",            404),
    "CONFLICT":            ProblemDetail("/errors/conflict",            "Conflict",             409),
    "INTERNAL_ERROR":      ProblemDetail("/errors/internal",            "Internal Server Error",500),
    "SERVICE_UNAVAILABLE": ProblemDetail("/errors/service-unavailable", "Service Unavailable",  503),
}

def problem_response(code: str, detail: str | None = None, **extensions):
    """Return a ProblemDetail dict for the given error code."""
    base = ERROR_CODES[code]
    return ProblemDetail(
        type=base.type, title=base.title, status=base.status,
        detail=detail, extensions=extensions,
    ).to_dict()
```

### 2.85c — Wire logger into app entrypoint

Find the app's main entrypoint and add a startup log line so the logger is immediately active:

**Node/Next.js:** Scan for entrypoint:
```bash
# Next.js instrumentation hook (preferred)
ls src/instrumentation.ts app/instrumentation.ts 2>/dev/null | head -1
# Express/Node entrypoint
grep -rlE '(createServer|app\.listen|export default app)' --include="*.ts" --include="*.js" src/ app/ . 2>/dev/null | head -1
```

- **If `instrumentation.ts` exists or is supported** (Next.js 13.4+): add logger import + startup log:
  ```typescript
  import { logger } from '@/lib/logger'
  export function register() { logger.info('Application started') }
  ```
- **If Express/Node entrypoint found**: add `import { logger } from './lib/logger'` and `logger.info('Server started', { port })` near the listen call.
- **If no entrypoint found**: skip wiring, print instructions.

**Python:** Scan for entrypoint:
```bash
grep -rlE '(uvicorn\.run|app\.run|wsgi|asgi|manage\.py)' --include="*.py" . 2>/dev/null | head -1
```

- **If Django `manage.py` or `wsgi.py` found**: add `from app.logging import get_logger; logger = get_logger(); logger.info("Server started")` in the appropriate file.
- **If FastAPI/Flask entrypoint found**: add logger import + startup log near app creation.
- **If no entrypoint found**: skip wiring, print instructions.

**Rules for wiring:**
- Add only one import line and one log line — no other changes
- If the file already imports a logger, skip — print "Logger already wired"
- Never modify existing log statements

### 2.85d — Wire into app error handler

Scan the project for the existing global error handler:
- **Next.js**: look for `app/error.tsx`, `pages/_error.tsx`, or API route error middleware
- **Express**: look for `app.use((err, req, res, next)` pattern
- **Django**: look for custom exception handler in `REST_FRAMEWORK` settings or `handler500`
- **FastAPI**: look for `@app.exception_handler`
- **Rails**: look for `rescue_from` in ApplicationController

**If found:** add a comment pointing to the new `errors.ts` / `errors.py` and suggest wiring it in. Do NOT auto-modify the error handler — print instructions instead:
```
Error handler found at [path]:[line].
Wire in RFC 9457 responses:
  import { problemResponse, ErrorCodes } from '@/lib/errors'
  // Then use: return problemResponse('NOT_FOUND', 'User not found')
```

**If no global error handler found:** print a note:
```
No global error handler detected.
Error utilities written — use them when adding API routes:
  import { problemResponse } from '@/lib/errors'
```

Print:
```
OBSERVABILITY
══════════════════════════════════════
  Logging:    structured (OTel format) → [src/lib/logger.ts | app/logging.py]
  Logger:     [wired into entrypoint | manual — see import instructions]
  Errors:     RFC 9457 Problem Details → [src/lib/errors.ts | app/errors.py]
  Error codes: 7 base codes — extend in errors file
══════════════════════════════════════
```

---

## Step 2.9 — Smoke test (validate auth chain)

If a dev login route was scaffolded or detected in Step 2.75, run a quick Playwright smoke test to validate the full auth chain works before `/vb-simulate` is run.

**Skip if:** no dev login path set, or Playwright not installed, or no dev server currently running.

```bash
# Check prerequisites
[ -z "$DEV_LOGIN_PATH" ] && echo "Smoke test: skipped (no dev login path)" && SMOKE_SKIP=true
[ "$SMOKE_SKIP" != "true" ] && ! npx playwright --version 2>/dev/null && echo "Smoke test: skipped (Playwright not installed)" && SMOKE_SKIP=true
```

**If prerequisites met:** check if server is running, then write and run a minimal smoke test:

```bash
# Try common ports
SMOKE_PORT=""
for port in 3000 3001 5173 8000 8080; do
  curl -sf "http://localhost:$port" >/dev/null 2>&1 && SMOKE_PORT=$port && break
done
[ -z "$SMOKE_PORT" ] && echo "Smoke test: skipped (no dev server running — start with 'make dev' then re-run)" && SMOKE_SKIP=true
```

Write `.vibekit/_pw_smoke.mjs`:
```js
import { chromium } from 'playwright';
const port = process.env.SMOKE_PORT || '3000';
const loginPath = process.env.DEV_LOGIN_PATH || '/dev-login';

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();

const results = { passed: [], failed: [] };
const roles = (process.env.SMOKE_ROLES || 'admin,user').split(',');

for (const role of roles) {
  try {
    const url = `http://localhost:${port}${loginPath}?role=${role.trim()}`;
    const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 10000 });
    // After login, should redirect away from login page
    const finalUrl = page.url();
    const onLoginPage = finalUrl.includes(loginPath);
    if (resp.status() < 400 && !onLoginPage) {
      results.passed.push(role.trim());
    } else {
      results.failed.push({ role: role.trim(), status: resp.status(), url: finalUrl });
    }
  } catch (e) {
    results.failed.push({ role: role.trim(), error: e.message });
  }
}

await browser.close();
console.log(JSON.stringify(results));
```

```bash
SMOKE_ROLES=$(grep -oE '"User Roles"' docs/PRODUCT.md >/dev/null 2>&1 && \
  grep -A20 "User Roles" docs/PRODUCT.md | grep -oE '^\| [A-Za-z]+' | sed 's/| //' | tr '\n' ',' || echo "admin,user")
SMOKE_PORT=$SMOKE_PORT DEV_LOGIN_PATH=$DEV_LOGIN_PATH SMOKE_ROLES=$SMOKE_ROLES \
  node .vibekit/_pw_smoke.mjs > .vibekit/_pw_smoke.json 2>/dev/null
rm -f .vibekit/_pw_smoke.mjs
```

Read the JSON results:
- **All passed:** print `Smoke test: PASS — [N] roles authenticated successfully`
- **Some failed:** print warnings with details — do not block setup
- Clean up: `rm -f .vibekit/_pw_smoke.json`

```
SMOKE TEST
══════════════════════════════════════
  Server:   http://localhost:[SMOKE_PORT]
  Login:    [DEV_LOGIN_PATH]
  Roles:    [list]
  Result:   [PASS — N/N | PARTIAL — N/N passed | SKIPPED — reason]
══════════════════════════════════════
```

---

## Step 3 — Session hook auto-install

Create `.claude/hooks/session-start.sh`:

```bash
mkdir -p .claude/hooks
```

Write `.claude/hooks/session-start.sh`:
```bash
#!/bin/bash
BRANCH="$(git branch --show-current 2>/dev/null)"
echo "=== vibekit — $(basename $(git rev-parse --show-toplevel)) ==="
echo "Branch: $BRANCH"
echo ""
if ! gh auth status &>/dev/null; then
  echo "gh not authenticated — run: gh auth login"
  echo "Then run /vb-setup to initialise this project."
  exit 0
fi
HIGHLIGHTS=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
if [ -z "$HIGHLIGHTS" ]; then
  echo "Project not initialised — run /vb-setup first."
  exit 0
fi
BUG_COUNT=$(gh issue list --label "bug" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
CARRY_COUNT=$(gh issue list --label "carry" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
echo "Open bugs: $BUG_COUNT  |  Arch: $ARCH_COUNT  |  Carry: $CARRY_COUNT"
gh issue list --label "bug,critical" --state open --limit 3 --json number,title \
  --jq '.[] | "  CRITICAL #\(.number) — \(.title)"' 2>/dev/null
gh issue list --label "bug,high" --state open --limit 3 --json number,title \
  --jq '.[] | "  HIGH     #\(.number) — \(.title)"' 2>/dev/null
echo ""
gh issue list --label "cycle" --state all --limit 1 --json title,createdAt \
  --jq '.[] | "Last cycle: \(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "Last cycle: none"
echo ""
if gh issue list --label "bug,critical" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null | grep -q .; then
  echo "NEXT: /vb-simulate — critical bugs open"
elif [ "$ARCH_COUNT" -gt "0" ] 2>/dev/null; then
  echo "NEXT: /vb-build ($ARCH_COUNT arch issues) or /vb-simulate (next cycle)"
else
  echo "NEXT: /vb-simulate (continuous) or /vb-launch (ready to ship)"
fi
echo "======================================="
```

```bash
chmod +x .claude/hooks/session-start.sh
```

Then merge hook config into `.claude/settings.json`:
- If file doesn't exist: create it with the hook config
- If file exists: read it, merge the `SessionStart` hook into the `hooks` object (preserve any existing hooks)

Hook config to merge:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-start.sh",
            "timeout": 15,
            "statusMessage": "Loading project state..."
          }
        ]
      }
    ]
  }
}
```

Print: `Session hook: installed (shows issue state on Claude Code start)`

---

## Step 3.5 — Private repo detect + session stop hook

Detect repo privacy and persist:
```bash
mkdir -p .vibekit
IS_PRIVATE=$(gh repo view --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "false")
REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || basename "$(git rev-parse --show-toplevel)")
echo "IS_PRIVATE=${IS_PRIVATE}" > .vibekit/repo.env
echo "REPO_NAME=${REPO_NAME}" >> .vibekit/repo.env
```

**If public repo (`IS_PRIVATE=false`):**
Print `Session logs: skipped (public repo)` and skip the rest of this step.

**If private repo (`IS_PRIVATE=true`):**


Write `.claude/hooks/session-stop.sh`:
```bash
#!/bin/bash
# vibekit session digest — zero LLM calls, pure jq + regex pipeline
set -euo pipefail

VIBEKIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.vibekit"
[ -d "$VIBEKIT_DIR" ] || exit 0

# Load repo context
[ -f "$VIBEKIT_DIR/repo.env" ] || exit 0
source "$VIBEKIT_DIR/repo.env"
[ "$IS_PRIVATE" = "true" ] || exit 0

# Step 1 — locate latest session transcript
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_HASH="$(echo "$PROJECT_ROOT" | sed 's|/|-|g')"
LATEST_JSONL=$(ls -t "$HOME/.claude/projects/${PROJECT_HASH}"/*.jsonl 2>/dev/null | head -1)
[ -n "$LATEST_JSONL" ] || exit 0

# Step 2 — secret scrubbing (before any extraction)
SAFE_JSONL="$VIBEKIT_DIR/safe-session-$$.jsonl"
sed -E \
  -e 's/(sk-[a-zA-Z0-9_-]{20,})/[REDACTED_API_KEY]/g' \
  -e 's/(ghp_[a-zA-Z0-9]{36})/[REDACTED_GH_TOKEN]/g' \
  -e 's/(github_pat_[a-zA-Z0-9_]{82})/[REDACTED_GH_PAT]/g' \
  -e 's/([A-Za-z0-9+\/]{40,}={0,2})/[REDACTED_B64]/g' \
  -e 's/(password|passwd|secret|token|api_?key|auth)[[:space:]]*[:=][[:space:]]*["'"'"']?[^"'"'"',\n}{]{6,}/\1=[REDACTED]/gi' \
  -e 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[IP_REDACTED]/g' \
  "$LATEST_JSONL" > "$SAFE_JSONL"

# Step 3 — extract full conversation transcript (from sanitized file)
TRANSCRIPT="$VIBEKIT_DIR/session-transcript-$$.txt"
SESSION_DATE="$(date '+%Y-%m-%d %H:%M')"

# Build interleaved user↔assistant turns
jq -r '
  . as $entry |
  if .type == "user" then
    (.message.content[]? | select(type == "object") |
      if .type == "text" then "**User:** " + .text
      elif .type == "tool_result" then
        "**Tool result:** " + ((.content[]? | select(.type=="text") | .text) // "" | .[0:300])
      else empty end)
  elif .type == "assistant" then
    (.message.content[]? | select(type == "object") |
      if .type == "text" then "**Claude:** " + .text
      elif .type == "tool_use" then "**Tool call:** `" + .name + "`"
      else empty end)
  else empty end
' "$SAFE_JSONL" 2>/dev/null \
  | grep -v '^[[:space:]]*$' \
  > "$TRANSCRIPT"

# Step 4 — gate on content
if [ "$(wc -l < "$TRANSCRIPT")" -lt 4 ]; then
  rm -f "$TRANSCRIPT" "$SAFE_JSONL"
  exit 0
fi

# Step 5 — collect stats and referenced issue numbers
TOOL_COUNT=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$SAFE_JSONL" 2>/dev/null | wc -l | tr -d ' ')
COMMITS=$(jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content[]? | select(.type=="text") | .text' "$SAFE_JSONL" 2>/dev/null | grep -oE '\b[0-9a-f]{7,12}\b' | sort -u | tr '\n' ' ')
TOUCHED_ISSUES=$(grep -oE '(#[0-9]+|issues/[0-9]+)' "$TRANSCRIPT" | grep -oE '[0-9]+' | sort -u)

HEADER="## vibekit session — ${REPO_NAME} — ${SESSION_DATE}
Tool calls: ${TOOL_COUNT} | Commits: ${COMMITS:-none}
Issues touched: $(echo "$TOUCHED_ISSUES" | tr '\n' ' ' | sed 's/ $//')"

# Step 6 — post full transcript to cycle issue (chunked at ~60KB)
CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
if [ -n "$CYCLE_ISSUE" ]; then
  CHUNK_SIZE=400  # lines per chunk
  TOTAL_LINES=$(wc -l < "$TRANSCRIPT")
  CHUNK_NUM=1
  OFFSET=1

  while [ "$OFFSET" -le "$TOTAL_LINES" ]; do
    CHUNK=$(sed -n "${OFFSET},$((OFFSET + CHUNK_SIZE - 1))p" "$TRANSCRIPT")
    PART_LABEL=""
    [ "$TOTAL_LINES" -gt "$CHUNK_SIZE" ] && PART_LABEL=" (part ${CHUNK_NUM})"

    if [ "$CHUNK_NUM" -eq 1 ]; then
      BODY="${HEADER}

<details><summary>Full transcript${PART_LABEL}</summary>

${CHUNK}
</details>"
    else
      BODY="<details><summary>Full transcript${PART_LABEL}</summary>

${CHUNK}
</details>"
    fi

    gh issue comment "$CYCLE_ISSUE" --body "$BODY" 2>/dev/null || true
    OFFSET=$((OFFSET + CHUNK_SIZE))
    CHUNK_NUM=$((CHUNK_NUM + 1))
  done

  echo "Session transcript posted to cycle issue #${CYCLE_ISSUE} (${CHUNK_NUM-1} part(s))"
fi

# Step 7 — post per-issue comments with only turns mentioning that issue
for ISSUE_NUM in $TOUCHED_ISSUES; do
  # Skip the cycle issue itself
  [ "$ISSUE_NUM" = "$CYCLE_ISSUE" ] && continue

  # Extract turns that reference this issue number
  ISSUE_TURNS=$(grep -n "#${ISSUE_NUM}\b" "$TRANSCRIPT" | cut -d: -f1 | while read -r LINE_NUM; do
    # Include surrounding context: 2 lines before and after each match
    START=$((LINE_NUM - 2)); [ "$START" -lt 1 ] && START=1
    END=$((LINE_NUM + 2))
    sed -n "${START},${END}p" "$TRANSCRIPT"
    echo "---"
  done | sort -u)

  [ -z "$ISSUE_TURNS" ] && continue

  ISSUE_BODY="<details><summary>Session activity — ${REPO_NAME} — ${SESSION_DATE}</summary>

${ISSUE_TURNS}
</details>"

  gh issue comment "$ISSUE_NUM" --body "$ISSUE_BODY" 2>/dev/null || true
  echo "Session activity posted to issue #${ISSUE_NUM}"
done

rm -f "$TRANSCRIPT" "$SAFE_JSONL"
```

```bash
chmod +x .claude/hooks/session-stop.sh
```

Merge Stop hook into `.claude/settings.json` (same pattern as SessionStart, preserve existing hooks):
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-stop.sh",
            "timeout": 30,
            "statusMessage": "Saving session digest..."
          }
        ]
      }
    ]
  }
}
```

Print: `Session stop hook: installed (private repo — full transcripts → cycle issue + per-ticket comments)`

---

## Step 3.6 — Scratch directory + .gitignore

Create `.vibekit/` — all simulation scripts, screenshots, and temp files go here, never the project root:

```bash
mkdir -p .vibekit
```

Write `.vibekit/.gitkeep` (keeps the dir in git without tracking contents).

Merge these entries into `.gitignore` (append only if not already present):

```
# vibekit — simulation temp files
.vibekit/*.mjs
.vibekit/*.json
.vibekit/*.png
.vibekit/*.jpg
.vibekit/repo.env
.vibekit/project.env
.vibekit/milestone.env
.vibekit/build.lock
.vibekit/session-digest-*.txt
.vibekit/safe-session-*.jsonl
_pw_*.mjs
_pw_*.json
_pw_*.png
```

The `_pw_*` glob is a safety net — if any script accidentally writes to the project root it is still ignored.

Print: `Scratch dir: .vibekit/ created | .gitignore: updated`

---

## Step 4 — GitHub labels (idempotent)

```bash
gh label create "sim"       --color "0075ca" --description "From a simulation cycle"            2>/dev/null || true
gh label create "bug"       --color "d73a4a" --description "Fixable code issue"                 2>/dev/null || true
gh label create "arch"      --color "e4e669" --description "Needs /vb-build to implement"  2>/dev/null || true
gh label create "carry"     --color "ff6b35" --description "Bug surviving 2+ cycles unfixed"    2>/dev/null || true
gh label create "highlight" --color "0e8a16" --description "Positive signal for GTM artifacts"  2>/dev/null || true
gh label create "cycle"     --color "5319e7" --description "Parent issue per simulation cycle"  2>/dev/null || true
gh label create "wontfix"   --color "ffffff" --description "Triaged out"                        2>/dev/null || true
gh label create "v0.1"      --color "1d76db" --description "Launch milestone"                   2>/dev/null || true
gh label create "critical"  --color "b60205" --description "Severity: critical"                 2>/dev/null || true
gh label create "high"      --color "e11d48" --description "Severity: high"                     2>/dev/null || true
gh label create "medium"    --color "f97316" --description "Severity: medium"                   2>/dev/null || true
gh label create "low"       --color "84cc16" --description "Severity: low"                      2>/dev/null || true
gh label create "review"    --color "6f42c1" --description "From a /vb-review audit"        2>/dev/null || true
gh label create "vibekit"   --color "7057ff" --description "Trigger auto-implementation in /vb-build"  2>/dev/null || true
```

---

## Step 4.25 — GitHub Actions CI

```bash
test -f .github/workflows/ci.yml && echo "exists" || echo "missing"
```

**If CI workflow already exists:** print `CI: .github/workflows/ci.yml already exists — skipping.` and skip this step.

**If missing:** detect stack and write the appropriate workflow:

**Node/pnpm** (when `package.json` present):

Before writing the workflow, detect the Node version to use:
```bash
# Prefer .nvmrc, then package.json engines.node, then default to 20
if [ -f ".nvmrc" ]; then
  NODE_VERSION=$(cat .nvmrc | tr -d 'v\n')
else
  NODE_VERSION=$(node -e "const p=require('./package.json'); const e=(p.engines||{}).node||''; const m=e.match(/[\d]+/); console.log(m?m[0]:'20')" 2>/dev/null || echo "20")
fi
```

```yaml
name: CI
on:
  push:
    branches: [develop]
  pull_request:
    branches: [develop, main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: latest
      - uses: actions/setup-node@v4
        with:
          node-version: '[NODE_VERSION detected above]'
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm test
```

**Python/uv** (when `pyproject.toml` or `requirements.txt` present):
```yaml
name: CI
on:
  push:
    branches: [develop]
  pull_request:
    branches: [develop, main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync
      - run: uv run pytest
```

```bash
mkdir -p .github/workflows
# Write the appropriate ci.yml above
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions CI workflow"
git push origin develop
```

Print: `CI: .github/workflows/ci.yml created and pushed to develop`

---

## Step 4.5 — GitHub Projects board

```bash
OWNER=$(gh api user --jq '.login')
PROJECT_TITLE="vibekit — $(gh repo view --json name --jq '.name')"
```

Idempotent create — check for existing project first:
```bash
EXISTING=$(gh project list --owner "@me" --format json \
  --jq ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number" 2>/dev/null | head -1)
if [ -z "$EXISTING" ]; then
  PROJECT_NUMBER=$(gh project create --owner "@me" --title "$PROJECT_TITLE" --format json --jq '.number')
  echo "Project board created: #${PROJECT_NUMBER}"
else
  PROJECT_NUMBER="$EXISTING"
  echo "Project board already exists: #${PROJECT_NUMBER}"
fi
```

Fetch project node ID and Status field option IDs via GraphQL:
```bash
# Get project ID and Status field options
gh api graphql -f query='
query($n:Int!,$owner:String!){
  user(login:$owner){
    projectV2(number:$n){
      id
      field(name:"Status"){
        ...on ProjectV2SingleSelectField{
          id
          options{ id name }
        }
      }
    }
  }
}' -F n="$PROJECT_NUMBER" -F owner="$OWNER" > .vibekit/project_meta.json 2>/dev/null || true
```

Parse and persist to `.vibekit/project.env`:
```bash
PROJECT_ID=$(jq -r '.data.user.projectV2.id' .vibekit/project_meta.json 2>/dev/null || echo "")
STATUS_FIELD_ID=$(jq -r '.data.user.projectV2.field.id' .vibekit/project_meta.json 2>/dev/null || echo "")

# Map column names to option IDs — columns: "Sim Queue", "In Progress", "Fixed", "Arch Backlog", "Done"
STATUS_OPT_SIM_QUEUE=$(jq -r '.data.user.projectV2.field.options[] | select(.name=="Sim Queue") | .id' .vibekit/project_meta.json 2>/dev/null || echo "")
STATUS_OPT_IN_PROGRESS=$(jq -r '.data.user.projectV2.field.options[] | select(.name=="In Progress") | .id' .vibekit/project_meta.json 2>/dev/null || echo "")
STATUS_OPT_FIXED=$(jq -r '.data.user.projectV2.field.options[] | select(.name=="Fixed") | .id' .vibekit/project_meta.json 2>/dev/null || echo "")
STATUS_OPT_ARCH_BACKLOG=$(jq -r '.data.user.projectV2.field.options[] | select(.name=="Arch Backlog") | .id' .vibekit/project_meta.json 2>/dev/null || echo "")
STATUS_OPT_DONE=$(jq -r '.data.user.projectV2.field.options[] | select(.name=="Done") | .id' .vibekit/project_meta.json 2>/dev/null || echo "")

# Note: new projects use GitHub's default columns (Todo/In Progress/Done).
# If custom columns not found, fall back to available options gracefully.
# STATUS_OPT_* will be empty strings — add_to_project() checks before using.

echo "PROJECT_CONFIGURED=true" > .vibekit/project.env
echo "PROJECT_NUMBER=${PROJECT_NUMBER}" >> .vibekit/project.env
echo "PROJECT_ID=${PROJECT_ID}" >> .vibekit/project.env
echo "STATUS_FIELD_ID=${STATUS_FIELD_ID}" >> .vibekit/project.env
echo "STATUS_OPT_SIM_QUEUE=${STATUS_OPT_SIM_QUEUE}" >> .vibekit/project.env
echo "STATUS_OPT_IN_PROGRESS=${STATUS_OPT_IN_PROGRESS}" >> .vibekit/project.env
echo "STATUS_OPT_FIXED=${STATUS_OPT_FIXED}" >> .vibekit/project.env
echo "STATUS_OPT_ARCH_BACKLOG=${STATUS_OPT_ARCH_BACKLOG}" >> .vibekit/project.env
echo "STATUS_OPT_DONE=${STATUS_OPT_DONE}" >> .vibekit/project.env

rm -f .vibekit/project_meta.json
```

Print: `Projects board: #${PROJECT_NUMBER} — ${PROJECT_TITLE}`

---

## Step 4.75 — GitHub Milestone v0.1

Idempotent create:
```bash
EXISTING_MS=$(gh api repos/{owner}/{repo}/milestones \
  --jq '.[] | select(.title=="v0.1") | .number' 2>/dev/null | head -1)

if [ -z "$EXISTING_MS" ]; then
  MS_NUM=$(gh api repos/{owner}/{repo}/milestones -X POST \
    -f title="v0.1" \
    -f state="open" \
    -f description="First release — managed by vibekit" \
    --jq '.number')
  echo "Milestone created: v0.1 (#${MS_NUM})"
else
  MS_NUM="$EXISTING_MS"
  echo "Milestone already exists: v0.1 (#${MS_NUM})"
fi

echo "MILESTONE_NUMBER=${MS_NUM}" > .vibekit/milestone.env
echo "MILESTONE_TITLE=v0.1" >> .vibekit/milestone.env
```

Print: `Milestone: v0.1 (#${MS_NUM})`

---

## Step 4.8 — Daemon scaffold

Write the autonomous polling daemon to `.vibekit/daemon.sh` (skip if already exists):

```bash
[ -f ".vibekit/daemon.sh" ] && echo "Daemon: already exists — skipping" && DAEMON_EXISTS=true || DAEMON_EXISTS=false
```

If `DAEMON_EXISTS=false`, write `.vibekit/daemon.sh`:

```bash
#!/bin/bash
# vibekit autonomous daemon — polls for open issues and runs /vb-build --once
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$PROJECT_ROOT" ] || exit 1
cd "$PROJECT_ROOT"

VIBEKIT_DIR="$PROJECT_ROOT/.vibekit"
LOG="$VIBEKIT_DIR/daemon.log"
LOCK="$VIBEKIT_DIR/daemon.lock"
MAX_LOG_LINES=2000

if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt "$MAX_LOG_LINES" ]; then
  tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

if [ -f "$LOCK" ]; then
  LOCK_PID=$(cat "$LOCK" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    log "Already running (pid $LOCK_PID) — skipping"
    exit 0
  fi
  rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

if ! gh auth status &>/dev/null 2>&1; then
  log "ERROR: gh not authenticated — daemon paused"
  exit 1
fi

OPEN_COUNT=$(gh issue list --label "vibekit" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
TOTAL=$((OPEN_COUNT + ARCH_COUNT))

log "Poll: vibekit=$OPEN_COUNT arch=$ARCH_COUNT total=$TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  BUG_COUNT=$(gh issue list --label "bug" --state open --limit 10 --json number --jq 'length' 2>/dev/null || echo "1")
  REPO_NAME="$(basename "$PROJECT_ROOT")"

  if [ "$BUG_COUNT" -eq 0 ]; then
    log "All clear — triggering /vb-launch"
    osascript -e "display notification \"All issues resolved — running /vb-launch\" with title \"vibekit: $REPO_NAME\" sound name \"Glass\"" 2>/dev/null || true
    claude --print "/vb-launch" >> "$LOG" 2>&1
    LAUNCH_EXIT=$?
    if [ $LAUNCH_EXIT -eq 0 ]; then
      log "Launch complete"
      osascript -e "display notification \"Shipped! Check GitHub for the release.\" with title \"vibekit: $REPO_NAME ✓\" sound name \"Hero\"" 2>/dev/null || true
    else
      log "Launch failed (exit $LAUNCH_EXIT) — check logs"
      osascript -e "display notification \"/vb-launch failed — run /vb-daemon logs\" with title \"vibekit: $REPO_NAME ✗\" sound name \"Basso\"" 2>/dev/null || true
    fi
  else
    IDLE_STAMP="$VIBEKIT_DIR/.idle-notified"
    NOTIFY=true
    if [ -f "$IDLE_STAMP" ]; then
      LAST=$(cat "$IDLE_STAMP" 2>/dev/null || echo 0)
      NOW=$(date +%s)
      [ $((NOW - LAST)) -lt 3600 ] && NOTIFY=false
    fi
    if [ "$NOTIFY" = "true" ]; then
      log "Idle — $BUG_COUNT open bugs but no actionable tickets"
      osascript -e "display notification \"$BUG_COUNT open bugs — label issues 'vibekit' to resume\" with title \"vibekit: $REPO_NAME — idle\"" 2>/dev/null || true
      date +%s > "$IDLE_STAMP"
    fi
  fi
  exit 0
fi

log "Found $TOTAL open issues — starting /vb-build --once"
claude --print "/vb-build --once" >> "$LOG" 2>&1
EXIT_CODE=$?
log "Build complete (exit $EXIT_CODE)"

CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
if [ -n "$CYCLE_ISSUE" ]; then
  REMAINING=$(gh issue list --label "vibekit" --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "?")
  gh issue comment "$CYCLE_ISSUE" \
    --body "## Daemon run — $(date '+%Y-%m-%d %H:%M')
Started with $TOTAL open issues. Remaining: $REMAINING. Exit: $EXIT_CODE" 2>/dev/null || true
fi
```

```bash
chmod +x .vibekit/daemon.sh
```

Print: `Daemon scaffold: .vibekit/daemon.sh written — run /vb-daemon install to activate`

---

## Step 5 — Highlights Index issue

```bash
EXISTING=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty')
```

If empty:
```bash
HIGHLIGHTS_NUM=$(gh issue create \
  --title "Highlights Index" \
  --label "highlight" \
  --body "# Product Highlights Index

Tracks all positive signals observed during /vb-simulate cycles. Updated automatically — do not edit manually.

## Index
<!-- /vb-simulate appends entries here -->
" --json number --jq '.number')

# Pin the Highlights Index so it's always visible at the top of the Issues tab
gh issue pin "$HIGHLIGHTS_NUM" 2>/dev/null || true
```

---

## Step 6 — Summary

```
/vb-setup COMPLETE
════════════════════════════════════════════════════════
Project:        [repo name from git remote]
Branch:         develop
PRODUCT.md:     [created | already existed | refreshed]
CLAUDE.md:      [created | already existed | skipped]
Makefile:       [created | already existed | skipped]
Dev mode:       DEV_MODE=true in [.env.local | .env]
Dev login:      [/dev-login scaffolded | already existed | skipped]
Seed data:      [created | already existed]
Logging:        structured (OTel format) → [path]
Logger wired:   [yes — entrypoint | manual — see instructions]
Error handling: RFC 9457 Problem Details → [path]
Smoke test:     [PASS N/N roles | PARTIAL N/N | SKIPPED — reason]
Session hook:   installed
Session log hook: [installed — private repo | skipped — public repo]
CI workflow:    .github/workflows/ci.yml
Projects board: #[N] — vibekit — [repo]
Milestone:      v0.1 (#[N])
Labels:         14 confirmed (added: vibekit)
Highlights Index: #[N]

THE LOOP:
  /vb-simulate   — find & fix issues → GitHub Issues
  /vb-build      — full loop: build → simulate → repeat (one approval → autonomous)
  /vb-launch     — release gates → GitHub release → merge to main

MORE:
  /vb-review     — code review (security, quality, UI) + test generation (--test)
  /vb-pitch      — docs (--sales/--dev/--investor), status (--status), metrics (--metrics)

START:
  make dev            ← starts app locally + DBs in Docker
  make run            ← everything in Docker (full stack)
  make seed           ← load dev data
  make clean          ← wipe all containers + volumes

  /vb-simulate   ← find & fix issues (runs indefinitely)
════════════════════════════════════════════════════════
```
