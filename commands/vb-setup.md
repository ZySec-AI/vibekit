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

Ensure gist OAuth scope is available:
```bash
gh auth refresh -s gist 2>/dev/null || true
```

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

# Step 3 — extract digest (from sanitized file)
DIGEST="$VIBEKIT_DIR/session-digest-$$.txt"
echo "# vibekit session — ${REPO_NAME} — $(date '+%Y-%m-%d %H:%M')" > "$DIGEST"

echo "## Decisions & Actions" >> "$DIGEST"
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
  "$SAFE_JSONL" 2>/dev/null \
  | grep -iE '(fix|escalat|arch|skip|severity|commit|bug|wontfix|implement|close|defer|block)' \
  | grep -v '^[[:space:]]*$' \
  | sed 's/^[[:space:]]*//' \
  | head -40 >> "$DIGEST"

echo "## Issues Touched" >> "$DIGEST"
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content[]? | select(.type=="text") | .text' \
  "$SAFE_JSONL" 2>/dev/null \
  | grep -oE '(#[0-9]+|issues/[0-9]+)' | sort -u >> "$DIGEST"

echo "## Commits" >> "$DIGEST"
jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content[]? | select(.type=="text") | .text' \
  "$SAFE_JSONL" 2>/dev/null \
  | grep -oE '\b[0-9a-f]{7,12}\b' | sort -u >> "$DIGEST"

echo "## Activity" >> "$DIGEST"
TOOL_COUNT=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$SAFE_JSONL" 2>/dev/null | wc -l | tr -d ' ')
echo "Tool calls: ${TOOL_COUNT}" >> "$DIGEST"

# Step 4 — gate on content, push as secret gist
if [ "$(wc -l < "$DIGEST")" -lt 8 ]; then
  rm -f "$DIGEST" "$SAFE_JSONL"
  exit 0
fi

GIST_URL=$(gh gist create --desc "vibekit session — ${REPO_NAME} — $(date '+%Y-%m-%d')" "$DIGEST" 2>/dev/null || true)
rm -f "$DIGEST" "$SAFE_JSONL"

if [ -n "$GIST_URL" ]; then
  CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
  [ -n "$CYCLE_ISSUE" ] && gh issue comment "$CYCLE_ISSUE" --body "Session log: $GIST_URL" 2>/dev/null || true
  echo "Session digest: $GIST_URL"
fi
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

Print: `Session stop hook: installed (private repo — session digests → secret gists)`

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
gh label create "vibekit"   --color "7057ff" --description "Trigger auto-implementation in daemon mode" 2>/dev/null || true
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
Session hook:   installed
Session log hook: [installed — private repo | skipped — public repo]
CI workflow:    .github/workflows/ci.yml
Projects board: #[N] — vibekit — [repo]
Milestone:      v0.1 (#[N])
Labels:         14 confirmed (added: vibekit)
Highlights Index: #[N]

THE LOOP:
  /vb-simulate   — find & fix issues → GitHub Issues
  /vb-build      — implement [Arch] issues (one approval → autonomous)
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
