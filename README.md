# Product Loop Plugin

A 4-command autonomous product development loop for Claude Code. Simulate customers, fix bugs, implement features, and ship — all from the command line.

Works with any web app that has a dev server and a GitHub remote.

---

## Commands

| Command | What it does |
|---------|-------------|
| `/setup` | Bootstrap a new project — checks prerequisites, creates GitHub labels, creates Highlights Index issue |
| `/simulate` | Customer journey simulation (Playwright) + 9-dimension UX audit + inline bug fixes → GitHub Issues |
| `/build` | Implements open `[Arch]` GitHub Issues. One approval → fully autonomous |
| `/launch` | Gates on open bugs, generates GTM artifacts, creates GitHub release, merges to main |

---

## Install

```bash
# In any project directory, open Claude Code and run:
/plugin install github:YOUR_ORG/scalerisk-plugin
```

Or add directly to `.claude/settings.json`:
```json
{
  "plugins": ["github:YOUR_ORG/scalerisk-plugin"]
}
```

---

## Quick Start

1. **Install the plugin** (above)
2. **Run `/setup`** — bootstraps GitHub labels, checks prerequisites, creates `docs/PRODUCT.md` if missing
3. **Start your dev server** (e.g. `pnpm dev`, `npm run dev`)
4. **Run `/simulate`** — finds bugs, fixes them inline, creates GitHub Issues for architectural gaps
5. **Run `/build`** — implements the arch issues (one approval, then autonomous)
6. **Run `/launch`** — when ready to ship

```
/setup → /simulate → /build → /simulate → /launch
```

---

## The Loop

```
/simulate runs indefinitely (Ctrl+C to stop):
  ├── Customer journey simulation via Playwright
  │     └── ICP personas → UI journeys → bugs/enhancements → fix inline → commit
  ├── UX audit (9 dimensions × all pages × 3 iterations)
  │     └── theme, components, overflow, content, spacing, nav, IA, navbar, world-class standard
  ├── All fixable bugs committed to develop
  ├── Architectural gaps → open [Arch] GitHub Issues
  └── Wow moments → docs/HIGHLIGHTS.md + GitHub Highlights Index

/build runs once per batch of arch issues:
  ├── Reads all open [Arch] issues
  ├── Shows work plan → waits for one approval
  ├── Implements each issue with Playwright verification
  └── Commits + closes issues autonomously

/launch gates and ships:
  ├── Blocks if any critical/high bugs are open
  ├── Generates: SALES-PLAY.md, PRODUCT-BROCHURE.md, PRODUCT-DOCS.md, RELEASE-NOTES.md
  ├── Creates GitHub release with tag
  └── Merges develop → main
```

---

## Prerequisites

All 4 commands require:

- **`gh` CLI** — `brew install gh` then `gh auth login`
- **`git remote`** — repo must have a GitHub remote

`/simulate` and `/build` also require:
- **Playwright MCP** — configured in Claude Code settings
- **Dev server** — running locally (commands will start it with `pnpm dev` if not found)

---

## What Gets Created

### GitHub Labels (12, created by `/setup`)

| Label | Meaning |
|-------|---------|
| `sim` | From a simulation cycle |
| `bug` | Fixable code issue — auto-closed when fixed |
| `arch` | Needs `/build` to implement |
| `carry` | Bug surviving 2+ cycles unfixed |
| `highlight` | Positive signal for GTM artifacts |
| `cycle` | Parent issue per simulation cycle |
| `wontfix` | Triaged out |
| `v1.0` | Launch milestone |
| `critical` / `high` / `medium` / `low` | Severity |

### Files written to `docs/`

| File | Written by | Contents |
|------|-----------|----------|
| `PRODUCT.md` | `/setup` (if missing) | ICP, roles, competitive context — read by all commands |
| `HIGHLIGHTS.md` | `/simulate` | Observed wow moments, features that resonated |
| `DEMO-SEQUENCE.md` | `/simulate` | Recommended demo order per buyer type |
| `SALES-PLAY.md` | `/launch` | Battlecard for AEs and SEs |
| `PRODUCT-BROCHURE.md` | `/launch` | Customer-facing capability overview |
| `PRODUCT-DOCS.md` | `/launch` | Technical reference for evaluators |
| `RELEASE-NOTES.md` | `/launch` | Changelog for the release |

---

## docs/PRODUCT.md

The one file you must have (or let `/setup` generate). All 4 commands read it to understand:
- Who your ICP is
- What roles exist in the product
- What the top pain points are
- Who competitors are

If it doesn't exist, `/setup` will ask you 3 questions and generate it from your codebase.

---

## Idempotency

All commands are safe to restart after interruption:
- Issues are checked for existence before creation — no duplicates
- Commits already pushed survive a restart
- Cycle N detection reads GitHub Issues — no local state needed
- Partial cycles pick up from the last open unfixed bug

---

## Session Hook (optional)

Add to your project's `.claude/settings.json` to get live issue state printed at every session start:

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

And add `.claude/hooks/session-start.sh` to your repo (see the Scale Risk repo for the reference implementation).

---

## Version

1.0.0
