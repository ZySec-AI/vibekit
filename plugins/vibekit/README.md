# vibekit

**Autonomous product development loop for Claude Code.**

Simulate real customers, find and fix bugs, implement features, and ship — all from four slash commands. No manual test plans. No separate QA cycle. No stale docs.

Built by [ZySec AI](https://zysec.ai).

---

## What it does

Most development loops look like this:

```
code → manually test → file ticket → forget about it → code
```

vibekit turns Claude Code into a self-driving quality loop:

```
/simulate  →  bugs fixed inline, arch gaps tracked in GitHub
/build     →  arch gaps implemented, one approval, fully autonomous
/launch    →  gates checked, GTM docs generated, GitHub release created
```

Every bug is found by a simulated customer using your actual UI. Every fix is committed and verified in the browser. Every improvement is tracked as a GitHub Issue — not a text file.

---

## Commands

| Command | What it does |
|---------|-------------|
| `/setup` | First-time setup — installs GitHub labels, checks prerequisites, generates `docs/PRODUCT.md` |
| `/simulate` | Runs customer journeys + 9-dimension UX audit, fixes all bugs inline, creates GitHub Issues |
| `/build` | Reads open `[Arch]` issues, shows a plan, gets one approval, implements everything autonomously |
| `/launch` | Checks release gates, generates GTM docs, creates GitHub release, merges to main |

---

## Install

### Requirements

| Tool | Purpose | Install |
|------|---------|---------|
| [Claude Code](https://claude.ai/code) | Runs all commands | `npm install -g @anthropic-ai/claude-code` |
| [GitHub CLI](https://cli.github.com) | Issue tracking | `brew install gh` then `gh auth login` |
| Git remote | Repo must be on GitHub | `git remote add origin <url>` |
| Playwright MCP | Browser automation for `/simulate` and `/build` | See [Playwright MCP setup](#playwright-mcp-setup) |

### Install the plugin

**Step 1 — Add vibekit as a marketplace (once per machine):**

```bash
claude plugin marketplace add ZySec-AI/vibekit --scope user
```

**Step 2 — Install the plugin into your project:**

```bash
claude plugin install vibekit@ZySec-AI/vibekit
```

All four commands (`/setup`, `/simulate`, `/build`, `/launch`) are now available.

> **Sharing with your team:** Each person runs these two commands once. Or add to your project's `.claude/settings.json`:
> ```json
> { "plugins": ["vibekit@ZySec-AI/vibekit"] }
> ```
> After adding the marketplace on their machine, the plugin installs automatically when they open Claude Code in the project.

---

## Getting started

### Step 1 — Run `/setup` once

```
/setup
```

This will:
- Verify all prerequisites are installed
- Create 12 GitHub labels in your repo (`bug`, `arch`, `carry`, `highlight`, etc.)
- Create a Highlights Index issue for tracking positive signals
- Generate `docs/PRODUCT.md` if it doesn't exist (asks you 3 questions about your product)

### Step 2 — Start your dev server

```bash
pnpm dev   # or npm run dev, yarn dev, python manage.py runserver, etc.
```

vibekit's `/simulate` command will auto-detect the running port. If nothing is running, it will try `pnpm dev` automatically.

### Step 3 — Run `/simulate`

```
/simulate
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

### Step 4 — Run `/build` when arch issues accumulate

```
/build
```

Shows you a prioritised list of open `[Arch]` issues with implementation plan. You say yes. It implements, verifies in the browser, commits, and closes each issue — no further input needed.

### Step 5 — Run `/launch` when ready to ship

```
/launch --dry-run   # check gates first
/launch             # full release
```

---

## The full picture

### `/simulate` in detail

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
    └── Critical/high open? → "Run /build" | Clean → "Ready"
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
| 8 | Navbar quality | Item counts (4–7 by tier), labels clear to first-time users, click-count gate |
| 9 | World-class standard | First impression, actionability, trust signals, microcopy quality |

### What GitHub Issues look like after a cycle

```
[Bug] CISO dashboard — risk score shows "NaN" for tenants with no risks     [closed]
[Bug] Evidence upload — form submits with empty file, no validation error    [closed]
[Arch] Add PDF export to board report — requires new server action           [open]
[Arch] SIEM integration view — filter by framework control                  [open]
[Sim] Cycle 3 — 2026-03-10                                                  [open, parent]
```

Bugs are closed the moment they're fixed. Arch issues stay open until `/build`.

---

## docs/PRODUCT.md

The one file vibekit needs from you. It tells every command who your customers are, what roles exist, what pain points the product solves, and who competitors are.

It makes customer personas realistic. It makes GTM artifacts accurate. It makes the click-count checks role-appropriate.

If it doesn't exist, `/setup` will generate it by:
1. Reading your codebase (CLAUDE.md, README, src/ structure)
2. Asking you three questions:
   - What does this product do? (1-2 sentences)
   - Who is the primary buyer? (role title + industry)
   - What are the top 2-3 pain points it solves?

You can update it any time. All commands re-read it each run.

---

## What gets created in your repo

### GitHub Labels (created by `/setup`, idempotent)

| Label | Color | Meaning |
|-------|-------|---------|
| `sim` | blue | Anything from a simulation cycle |
| `bug` | red | Fixable code issue — auto-closed when fixed |
| `arch` | yellow | Needs `/build` — architectural change required |
| `carry` | orange | Bug surviving 2+ cycles without a fix |
| `highlight` | green | Positive signal — surfaces in GTM artifacts |
| `cycle` | purple | Parent issue per simulation cycle |
| `wontfix` | white | Triaged out |
| `v1.0` | blue | Launch milestone |
| `critical` / `high` / `medium` / `low` | red→green | Severity |

### Files written to `docs/`

| File | Written by | What it contains |
|------|-----------|-----------------|
| `docs/PRODUCT.md` | `/setup` | ICP, roles, competitive context — source of truth for all commands |
| `docs/HIGHLIGHTS.md` | `/simulate` | Observed customer wow moments, features that resonated |
| `docs/DEMO-SEQUENCE.md` | `/simulate` | Recommended demo order per buyer vertical |
| `docs/SALES-PLAY.md` | `/launch` | AE/SE battlecard with objection handling |
| `docs/PRODUCT-BROCHURE.md` | `/launch` | Customer-facing capability overview |
| `docs/PRODUCT-DOCS.md` | `/launch` | Technical reference for evaluators |
| `docs/RELEASE-NOTES.md` | `/launch` | Changelog for the release |

---

## Session hook (recommended)

Add this to your project's `.claude/settings.json` to see live issue state every time you open Claude Code:

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

Create `.claude/hooks/session-start.sh` in your repo:

```bash
#!/bin/bash
BRANCH="$(git branch --show-current 2>/dev/null)"
echo "=== vibekit — $(basename $(git rev-parse --show-toplevel)) ==="
echo "Branch: $BRANCH"
echo ""
if ! gh auth status &>/dev/null; then
  echo "gh not authenticated — run: gh auth login"
  echo "Then run /setup to initialise this project."
  exit 0
fi
HIGHLIGHTS=$(gh issue list --search "Highlights Index" --state all --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null)
if [ -z "$HIGHLIGHTS" ]; then
  echo "Project not initialised — run /setup first."
  exit 0
fi
BUG_COUNT=$(gh issue list --label "bug" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
ARCH_COUNT=$(gh issue list --label "arch" --state open --limit 50 --json number --jq 'length' 2>/dev/null || echo "?")
echo "Open bugs: $BUG_COUNT  |  Open arch issues: $ARCH_COUNT"
gh issue list --label "bug,critical" --state open --limit 3 --json number,title \
  --jq '.[] | "  CRITICAL #\(.number) — \(.title)"' 2>/dev/null
gh issue list --label "bug,high" --state open --limit 3 --json number,title \
  --jq '.[] | "  HIGH     #\(.number) — \(.title)"' 2>/dev/null
echo ""
gh issue list --label "cycle" --state all --limit 1 --json title,createdAt \
  --jq '.[] | "Last cycle: \(.title) (\(.createdAt[:10]))"' 2>/dev/null || echo "Last cycle: none"
echo ""
if gh issue list --label "bug,critical" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null | grep -q .; then
  echo "NEXT: /simulate — critical bugs open"
elif [ "$ARCH_COUNT" -gt "0" ] 2>/dev/null; then
  echo "NEXT: /build ($ARCH_COUNT arch issues) or /simulate (next cycle)"
else
  echo "NEXT: /simulate (continuous) or /launch (ready to ship)"
fi
echo "======================================="
```

Make it executable: `chmod +x .claude/hooks/session-start.sh`

---

## Playwright MCP setup

`/simulate` and `/build` use Playwright to run browser journeys and verify fixes. Add the Playwright MCP server to your Claude Code settings:

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
- **Anything** — `/simulate` tries ports 3000, 3001, 5173, 8000, 8080 and starts `pnpm dev` or `npm run dev` if none respond

The only hard requirement: a browser-accessible UI and a GitHub remote.

---

## FAQ

**Can I use this on a private repo?**
Yes. `gh` CLI works with private repos as long as you have access.

**Does it push directly to main?**
No. `/simulate` and `/build` push to `develop` only. `/launch` is the only command that touches `main`, and only after passing all gates.

**What if Playwright can't find an element?**
That becomes a bug issue. `/simulate` logs it, creates a GitHub Issue if needed, and moves on — it never stops because of a navigation failure.

**Can I run just the UX audit without customer journeys?**
Yes: `/simulate --cx-only`

**Can I run just journeys without the UX audit?**
Yes: `/simulate --journey-only`

**What if I don't have PRODUCT.md?**
`/setup` will generate it. Or create it manually — see the format in the Scale Risk reference implementation.

---

## About

**vibekit** is built and maintained by [ZySec AI](https://zysec.ai).

ZySec AI builds AI-powered security and GRC tools for regulated industries. vibekit is the internal development loop we use on our own products, open-sourced for the Claude Code community.

Questions or issues: open a GitHub Issue or reach out at [hello@zysec.ai](mailto:hello@zysec.ai).

---

## License

MIT © ZySec AI
