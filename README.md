# vibekit

**Autonomous product development loop for Claude Code.**

Most dev loops rely on manual testing, stale docs, and context switching to GitHub. vibekit closes the loop — simulated customers find bugs, Claude fixes them inline, and everything is tracked in GitHub Issues automatically.

Built by [ZySec AI](https://zysec.ai).

---

## Why vibekit

| Other approaches | vibekit |
|-----------------|---------|
| You manually test and file tickets | Simulated customers find bugs — Claude fixes them inline |
| QA is a separate cycle | UX audit runs every cycle across every page, 9 dimensions |
| Issues live in Slack threads or docs | Every bug, arch gap, and cycle tracked as GitHub Issues |
| GTM docs are written by hand, go stale | Generated from real observed customer behaviour |
| Shipping requires coordination | One command — gates checked, release created, merged to main |

---

## The loop

```
/vibekit-setup     →  codebase scan, PRODUCT.md, CLAUDE.md, session hook, labels (run once)
/vibekit-simulate  →  bugs fixed inline, arch gaps → GitHub Issues
/vibekit-build     →  one approval → arch issues implemented autonomously
/vibekit-pitch     →  generate all customer & developer docs from PRODUCT.md + codebase
/vibekit-launch    →  gates checked, GitHub release created, merged to main
/vibekit-review    →  deep code review (security, quality, UI) → GitHub Issues
/vibekit-test      →  generate & maintain persistent test suites
/vibekit-metrics   →  trend analysis across simulation cycles
/vibekit-status    →  project state at a glance (read-only)
```

---

## Install

From your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash
```

Then commit so your whole team gets the commands:

```bash
git add .claude/commands && git commit -m "chore: add vibekit commands"
```

**Global install** (all projects on this machine):

```bash
curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash -s -- --global
```

**Requirements:** [Claude Code](https://claude.ai/code) · [GitHub CLI](https://cli.github.com) (`gh auth login`) · [Playwright MCP](#playwright-mcp-setup)

---

## Getting started

**Quick start (zero questions):**

```
/vibekit-setup --auto
/vibekit-simulate
```

**Guided start:**

```
/vibekit-setup      # scans codebase, one prompt, generates PRODUCT.md + CLAUDE.md + session hook
make dev            # start your dev server
/vibekit-simulate   # runs indefinitely — Ctrl+C to stop
```

Each `/vibekit-simulate` cycle:
1. Generates realistic customer personas from your `docs/PRODUCT.md`
2. Runs UI journeys via Playwright
3. Fixes every fixable bug inline and commits to `develop`
4. Opens GitHub Issues for anything requiring architecture changes
5. Audits every page on 9 UX dimensions, fixes inline
6. Updates the Highlights Index with genuine product moments

When arch issues accumulate: `/vibekit-build` — shows a plan, one approval, fully autonomous.

Generate all docs: `/vibekit-pitch` — sales play, product brochure, API reference, architecture, pitch deck, and more.

When ready to ship: `/vibekit-launch` — gates, GitHub release, merge to main.

Review code quality: `/vibekit-review` — security, quality, and UI/accessibility audits with GitHub Issues.

Generate tests: `/vibekit-test` — scans for untested code, generates tests, runs them.

Track trends: `/vibekit-metrics` — bug velocity, severity trends, carry bug aging across cycles.

Check project state anytime: `/vibekit-status`

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

## Works with any web app

Next.js · React/Vite · Django · Rails · Laravel · anything with a browser-accessible UI and a GitHub remote.

---

## Playwright MCP setup

Add to `~/.claude/settings.json`:

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

Then: `npx playwright install chromium`

---

## About

**vibekit** is built and maintained by [ZySec AI](https://zysec.ai) — the internal development loop we use on our own products, open-sourced for the Claude Code community.

Questions: [hello@zysec.ai](mailto:hello@zysec.ai) · [GitHub Issues](https://github.com/ZySec-AI/vibekit/issues)

---

MIT © ZySec AI
