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
/setup     →  GitHub labels, PRODUCT.md, Highlights Index (run once)
/simulate  →  bugs fixed inline, arch gaps → GitHub Issues
/build     →  one approval → arch issues implemented autonomously
/launch    →  gates checked, GTM docs generated, GitHub release created
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

```bash
/setup      # one-time: labels, PRODUCT.md interview, Highlights Index
make dev    # start your dev server
/simulate   # runs indefinitely — Ctrl+C to stop
```

Each `/simulate` cycle:
1. Generates realistic customer personas from your `docs/PRODUCT.md`
2. Runs UI journeys via Playwright
3. Fixes every fixable bug inline and commits to `develop`
4. Opens GitHub Issues for anything requiring architecture changes
5. Audits every page on 9 UX dimensions, fixes inline
6. Updates the Highlights Index with genuine product moments

When arch issues accumulate: `/build` — shows a plan, one approval, fully autonomous.

When ready to ship: `/launch` — gates, GTM docs, GitHub release, merge to main.

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
