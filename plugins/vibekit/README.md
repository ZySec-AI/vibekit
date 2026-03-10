# vibekit

**Autonomous product development loop for Claude Code.**

Simulate real customers, find and fix bugs, implement features, generate docs, review code, generate tests, track metrics, and ship — all from nine slash commands. No manual test plans. No separate QA cycle. No stale docs.

Built by [ZySec AI](https://zysec.ai).

---

## What it does

Most development loops look like this:

```
code → manually test → file ticket → forget about it → code
```

vibekit turns Claude Code into a self-driving quality loop:

```
/vibekit-simulate  →  bugs fixed inline, arch gaps tracked in GitHub
/vibekit-build     →  arch gaps implemented, one approval, fully autonomous
/vibekit-launch    →  gates checked, GTM docs generated, GitHub release created
```

Every bug is found by a simulated customer using your actual UI. Every fix is committed and verified in the browser. Every improvement is tracked as a GitHub Issue — not a text file.

---

## Commands

| Command | What it does |
|---------|-------------|
| `/vibekit-setup` | First-time setup — scans codebase, generates `docs/PRODUCT.md` + `CLAUDE.md`, installs session hook, creates GitHub labels |
| `/vibekit-simulate` | Runs customer journeys + 9-dimension UX audit, fixes all bugs inline, creates GitHub Issues |
| `/vibekit-build` | Reads open `[Arch]` issues, shows a plan, gets one approval, implements everything autonomously |
| `/vibekit-pitch` | Generates all customer & developer docs from PRODUCT.md + HIGHLIGHTS.md + codebase |
| `/vibekit-launch` | Checks release gates, creates GitHub release, merges to main |
| `/vibekit-review` | Deep code review (security, quality, UI/accessibility), outputs GitHub Issues |
| `/vibekit-test` | Scans for untested code, generates persistent test suites, runs them |
| `/vibekit-metrics` | Trend analysis across simulation cycles — bug velocity, severity, carry bugs |
| `/vibekit-status` | Shows project state at a glance — issues, gates, recommended next command |

---

## Install

### Requirements

| Tool | Purpose | Install |
|------|---------|---------|
| [Claude Code](https://claude.ai/code) | Runs all commands | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com) | Issue tracking | `brew install gh` then `gh auth login` |
| Git remote | Repo must be on GitHub | `git remote add origin <url>` |
| Playwright MCP | Browser automation for `/vibekit-simulate` and `/vibekit-build` | See [Playwright MCP setup](#playwright-mcp-setup) |

### Install the plugin

**Step 1 — Add vibekit as a marketplace (once per machine):**

```bash
claude plugin marketplace add ZySec-AI/vibekit --scope user
```

**Step 2 — Install the plugin into your project:**

```bash
claude plugin install vibekit@ZySec-AI/vibekit
```

All nine commands are now available.

> **Sharing with your team:** Each person runs these two commands once. Or add to your project's `.claude/settings.json`:
> ```json
> { "plugins": ["vibekit@ZySec-AI/vibekit"] }
> ```
> After adding the marketplace on their machine, the plugin installs automatically when they open Claude Code in the project.

---

## Getting started

### Quick start (zero questions)

```
/vibekit-setup --auto
/vibekit-simulate
```

### Guided start

#### Step 1 — Run `/vibekit-setup` once

```
/vibekit-setup
```

This will:
- Verify all prerequisites are installed
- Scan your codebase (README, package.json, routes, models) and print what it found
- Ask one freeform prompt about your product — skip anything the scan already got right
- Generate `docs/PRODUCT.md` (draft-and-confirm flow)
- Generate `CLAUDE.md` if missing (project conventions)
- Install a session hook that shows issue state on Claude Code start
- Create 13 GitHub labels in your repo (`bug`, `arch`, `carry`, `highlight`, `review`, etc.)
- Create a Highlights Index issue for tracking positive signals

#### Step 2 — Start your dev server

```bash
pnpm dev   # or npm run dev, yarn dev, python manage.py runserver, etc.
```

vibekit's `/vibekit-simulate` command will auto-detect the running port. If nothing is running, it will try `pnpm dev` automatically.

#### Step 3 — Run `/vibekit-simulate`

```
/vibekit-simulate
```

It runs indefinitely (Ctrl+C to stop). Each cycle:

1. Generates realistic customer personas based on your `docs/PRODUCT.md`
2. Simulates those customers using your actual UI via Playwright
3. Finds bugs and UX issues
4. Fixes everything it can — inline, committed directly to `develop`
5. Creates `[Arch]` GitHub Issues for anything requiring schema/API/auth changes
6. Runs a full 9-dimension UX audit across every page
7. Updates `docs/HIGHLIGHTS.md` with genuine wow moments
8. Loops

#### Step 4 — Run `/vibekit-build` when arch issues accumulate

```
/vibekit-build
```

Shows you a prioritised list of open `[Arch]` issues with implementation plan. You say yes. It implements, verifies in the browser, commits, and closes each issue — no further input needed.

#### Step 5 — Generate docs with `/vibekit-pitch`

```
/vibekit-pitch              # all artifacts
/vibekit-pitch --sales      # sales play, brochure, demo sequence
/vibekit-pitch --dev        # API reference, architecture, onboarding guide
```

#### Step 6 — Run `/vibekit-launch` when ready to ship

```
/vibekit-launch --dry-run   # check gates first
/vibekit-launch             # full release
```

#### More commands

```
/vibekit-review             # deep code review (security, quality, UI)
/vibekit-review --pr 42     # review a specific PR
/vibekit-test               # generate tests for untested code
/vibekit-test --coverage    # run coverage, fill gaps
/vibekit-metrics            # trend analysis across cycles
/vibekit-metrics --export   # write docs/METRICS.md with Mermaid charts
```

---

## Command flags

### `/vibekit-setup`

| Flag | What it does |
|------|-------------|
| *(no flags)* | Scans codebase, asks one freeform prompt, generates PRODUCT.md + CLAUDE.md, installs session hook |
| `--auto` | Zero questions — generates PRODUCT.md entirely from codebase scan. `[INFERRED]` markers on uncertain sections. |
| `--refresh` | Re-scans codebase, diffs against existing PRODUCT.md, proposes updates for stale sections. |

### `/vibekit-pitch`

| Flag | What it does |
|------|-------------|
| *(no flags)* | Generates all artifacts (sales + dev + investor + one-pager + product docs) |
| `--sales` | GTM-focused: sales play, product brochure, demo sequence |
| `--dev` | Developer docs: API reference, architecture diagram (Mermaid), onboarding guide |
| `--investor` | Pitch deck as markdown slides |
| `--one-pager` | Single-page product overview |

### `/vibekit-review`

| Flag | What it does |
|------|-------------|
| *(no flags)* | Runs all dimensions (security + quality + UI) |
| `--security` | OWASP top 10, dependency CVEs, secrets in code, auth/authz |
| `--quality` | CLAUDE.md convention adherence, dead code, complexity, duplication |
| `--ui` | Accessibility (contrast, ARIA, keyboard nav), responsive issues |
| `--pr N` | Scope review to changes in PR #N only |
| `--fix` | Auto-fix fixable quality + UI issues, commit to develop |

### `/vibekit-test`

| Flag | What it does |
|------|-------------|
| *(no flags)* | Scans for untested code, generates all test types |
| `--unit` | Unit tests for business logic (models, utils, helpers) |
| `--integration` | Integration tests for API routes/handlers |
| `--e2e` | End-to-end Playwright test files |
| `--for "feature"` | Generate tests for a specific feature/module only |
| `--coverage` | Run existing tests, report coverage, generate tests for gaps |

### `/vibekit-metrics`

| Flag | What it does |
|------|-------------|
| *(no flags)* | Full history analysis, prints to console |
| `--cycle N` | Show metrics for a specific cycle |
| `--compare N..M` | Compare two cycles side by side |
| `--export` | Write `docs/METRICS.md` with Mermaid charts |

---

## The full picture

### `/vibekit-simulate` in detail

```
Each cycle:
  Phase 0 — Preflight
    ├── Check gh auth + git remote (hard fail if missing)
    ├── Read docs/PRODUCT.md for ICP context
    ├── Pull carry-forward bugs from GitHub Issues
    └── Determine cycle number from existing [Sim] issues

  Phase 1 — Customer Journeys
    ├── Generate ICP personas (parallel agents)
    ├── Run UI journeys via Playwright (sequential — shared browser)
    ├── Triage: bugs → fix inline | arch → GitHub Issue
    └── Commit one fix per bug, push to develop

  Phase 2 — UX Audit (3 iterations)
    ├── Visit every page as the correct role
    ├── Evaluate 9 dimensions per page (see below)
    ├── Cross-page IA + navbar audit
    ├── Fix all non-architectural issues inline
    └── Commit per fix group, push to develop

  Phase 3 — Dedup
    └── Close duplicate open bug issues

  Phase 4 — GitHub Output
    ├── Create [Sim] Cycle N parent issue
    └── Update Highlights Index issue + docs/HIGHLIGHTS.md

  Phase 5 — GTM Sync
    └── Regenerate docs/DEMO-SEQUENCE.md if highlights changed

  Phase 6 — Status
    └── Critical/high open? → "Run /vibekit-build" | Clean → "Ready"
```

### The 9 UX audit dimensions

Every page is scored on all 9. Anything below 7/10 gets improved.

| # | Dimension | What it checks |
|---|-----------|---------------|
| 1 | Theme consistency | No hardcoded colors, dark mode correct, typography follows design system |
| 2 | Component selection | Same data pattern = same component everywhere (StatusBadge, DataTable, KPI cards) |
| 3 | Content overflow | No horizontal scroll at 1280px, tables truncate correctly, empty states exist |
| 4 | Content representation | No raw `null`/`undefined`, status slugs humanized, numbers formatted |
| 5 | Spacing & hierarchy | One dominant CTA per page, density matches role tier |
| 6 | Navigation & wayfinding | Correct active state, breadcrumbs, primary actions top-right |
| 7 | Information architecture | Correct grouping, depth, progressive disclosure, cross-links |
| 8 | Navbar quality | Item counts (4-7 by tier), labels clear to first-time users, click-count gate |
| 9 | World-class standard | First impression, actionability, trust signals, microcopy quality |

### What GitHub Issues look like after a cycle

```
[Bug] CISO dashboard — risk score shows "NaN" for tenants with no risks     [closed]
[Bug] Evidence upload — form submits with empty file, no validation error    [closed]
[Arch] Add PDF export to board report — requires new server action           [open]
[Arch] SIEM integration view — filter by framework control                  [open]
[Sim] Cycle 3 — 2026-03-10                                                  [open, parent]
```

Bugs are closed the moment they're fixed. Arch issues stay open until `/vibekit-build`.

---

## docs/PRODUCT.md

The one file vibekit needs from you. It tells every command who your customers are, what roles exist, what pain points the product solves, and who competitors are.

It makes customer personas realistic. It makes GTM artifacts accurate. It makes the click-count checks role-appropriate.

If it doesn't exist, `/vibekit-setup` will generate it by:
1. Scanning your codebase (CLAUDE.md, README, package.json, routes, models, .env.example)
2. Printing what it found (tech stack, routes, roles, modules)
3. Asking one freeform prompt — skip anything the scan already got right
4. Drafting the full PRODUCT.md for your approval

Or skip the prompt entirely: `/vibekit-setup --auto`

You can update it any time. All commands re-read it each run. Use `/vibekit-setup --refresh` to re-scan and update stale sections.

---

## What gets created in your repo

### GitHub Labels (created by `/vibekit-setup`, idempotent)

| Label | Color | Meaning |
|-------|-------|---------|
| `sim` | blue | Anything from a simulation cycle |
| `bug` | red | Fixable code issue — auto-closed when fixed |
| `arch` | yellow | Needs `/vibekit-build` — architectural change required |
| `carry` | orange | Bug surviving 2+ cycles without a fix |
| `highlight` | green | Positive signal — surfaces in GTM artifacts |
| `cycle` | purple | Parent issue per simulation cycle |
| `wontfix` | white | Triaged out |
| `v1.0` | blue | Launch milestone |
| `review` | purple | From a `/vibekit-review` audit |
| `critical` / `high` / `medium` / `low` | red→green | Severity |

### Files written to `docs/`

| File | Written by | What it contains |
|------|-----------|-----------------|
| `docs/PRODUCT.md` | `/vibekit-setup` | ICP, roles, competitive context — source of truth for all commands |
| `docs/HIGHLIGHTS.md` | `/vibekit-simulate` | Observed customer wow moments, features that resonated |
| `docs/DEMO-SEQUENCE.md` | `/vibekit-simulate` | Recommended demo order per buyer vertical |
| `docs/SALES-PLAY.md` | `/vibekit-pitch` | AE/SE battlecard with objection handling |
| `docs/PRODUCT-BROCHURE.md` | `/vibekit-pitch` | Customer-facing capability overview |
| `docs/DEMO-SEQUENCE.md` | `/vibekit-pitch` | Recommended demo flows per buyer vertical |
| `docs/API-REFERENCE.md` | `/vibekit-pitch` | API endpoint reference from codebase scan |
| `docs/ARCHITECTURE.md` | `/vibekit-pitch` | Architecture overview with Mermaid diagrams |
| `docs/ONBOARDING.md` | `/vibekit-pitch` | Developer onboarding guide |
| `docs/PITCH-DECK.md` | `/vibekit-pitch` | Pitch deck as markdown slides |
| `docs/ONE-PAGER.md` | `/vibekit-pitch` | Single-page product overview |
| `docs/PRODUCT-DOCS.md` | `/vibekit-pitch` | Technical reference for evaluators |
| `docs/RELEASE-NOTES.md` | `/vibekit-launch` | Changelog for the release |
| `docs/METRICS.md` | `/vibekit-metrics` | Metrics dashboard with Mermaid charts (with `--export`) |

### Session hook (auto-installed by `/vibekit-setup`)

`/vibekit-setup` automatically installs a session hook that shows live issue state every time you open Claude Code. It creates:
- `.claude/hooks/session-start.sh` — the status script
- Merges hook config into `.claude/settings.json`

No manual setup needed.

---

## Playwright MCP setup

`/vibekit-simulate` and `/vibekit-build` use Playwright to run browser journeys and verify fixes. Add the Playwright MCP server to your Claude Code settings:

In `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

Then install browsers: `npx playwright install chromium`

---

## Idempotent by design

All commands are safe to stop and restart at any point:

- **No duplicate issues** — every `gh issue create` is preceded by a search; existing issues are skipped
- **No lost commits** — commits already pushed to `develop` are not re-applied
- **No lost cycle state** — cycle number and carry-forward bugs are read from GitHub Issues on every run
- **Partial cycles resume** — Phase 0 finds open unfixed bug issues from the current cycle and puts them back in the fix queue

---

## Compatible with any web app

vibekit doesn't assume a specific framework. It works with:

- **Next.js** — auto-detects `localhost:3000`, reads `src/app/` for page inventory
- **React / Vite** — detects `localhost:5173`
- **Django / Rails / Laravel** — detects common dev ports
- **Anything** — `/vibekit-simulate` tries ports 3000, 3001, 5173, 8000, 8080 and starts `pnpm dev` or `npm run dev` if none respond

The only hard requirement: a browser-accessible UI and a GitHub remote.

---

## FAQ

**Can I use this on a private repo?**
Yes. `gh` CLI works with private repos as long as you have access.

**Does it push directly to main?**
No. `/vibekit-simulate` and `/vibekit-build` push to `develop` only. `/vibekit-launch` is the only command that touches `main`, and only after passing all gates.

**What if Playwright can't find an element?**
That becomes a bug issue. `/vibekit-simulate` logs it, creates a GitHub Issue if needed, and moves on — it never stops because of a navigation failure.

**Can I run just the UX audit without customer journeys?**
Yes: `/vibekit-simulate --cx-only`

**Can I run just journeys without the UX audit?**
Yes: `/vibekit-simulate --journey-only`

**What if I don't have PRODUCT.md?**
`/vibekit-setup` will generate it. Use `--auto` for zero questions, or the default guided flow with one freeform prompt.

**How do I update PRODUCT.md after my product evolves?**
Run `/vibekit-setup --refresh` — it re-scans the codebase, diffs against the existing file, and proposes updates.

**How do I generate sales/marketing docs?**
Run `/vibekit-pitch` — it generates all customer and developer-facing artifacts from PRODUCT.md + HIGHLIGHTS.md + codebase scan. Use `--sales`, `--dev`, `--investor`, or `--one-pager` for specific subsets.

**Can I review a specific PR?**
Yes: `/vibekit-review --pr 42` — scopes the review to changes in that PR only.

**Does `/vibekit-test` require a specific test framework?**
No. It auto-detects Jest, Vitest, pytest, RSpec, Go testing, and more. It reads existing test patterns and generates tests that match your project's conventions.

**How do I track quality trends across cycles?**
Run `/vibekit-metrics` — it reads GitHub Issues history to show bug velocity, severity trends, carry bug aging, and recommendations. Use `--export` to write `docs/METRICS.md` with Mermaid charts.

---

## About

**vibekit** is built and maintained by [ZySec AI](https://zysec.ai).

ZySec AI builds AI-powered security and GRC tools for regulated industries. vibekit is the internal development loop we use on our own products, open-sourced for the Claude Code community.

Questions or issues: open a GitHub Issue or reach out at [hello@zysec.ai](mailto:hello@zysec.ai).

---

## License

MIT © ZySec AI
