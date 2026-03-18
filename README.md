<p align="center">
  <img src="docs/zysec-logo.svg" alt="ZySec AI" width="60"/>
</p>

# vibekit

**Your product gets better while you sleep.**

Simulated customers find bugs. Claude fixes them. Everything ships to GitHub automatically. No tickets. No QA cycle. No coordination.

Built by [ZySec AI](https://zysec.ai).

---

## Quickstart

### Step 1 — Install once per machine

```bash
curl -fsSL https://raw.githubusercontent.com/ZySec-AI/vibekit/refs/heads/develop/install.sh | bash
```

Installs 7 commands, session hooks, and the autonomous daemon into `~/.claude/`. Works across all your projects.

**Requirements:** [Claude Code](https://claude.ai/code) + [GitHub CLI](https://cli.github.com) + Node.js

```bash
gh auth login   # if not already authenticated
```

### Step 2 — Bootstrap each project (once per repo)

```bash
cd your-project
/vb-setup --auto    # scans codebase, creates GitHub labels, scaffolds PRODUCT.md + CLAUDE.md
```

### Step 3 — Run the loop

```bash
make dev            # start your dev server
/vb-simulate        # simulated customers find & fix bugs — runs until you stop it
/vb-build           # implements architectural issues, re-simulates, repeats
/vb-launch          # quality gates → GitHub release → merge to main
```

### Optional — Autonomous mode (no Claude session needed)

```bash
/vb-daemon install  # installs a background daemon that polls GitHub every 3 min
                    # finds open issues → runs /vb-build --once → auto-launches when clean
/vb-daemon status   # check daemon health
/vb-daemon logs     # tail the daemon log
```

---

## How it works

<p align="center">
  <img src="docs/vibekit-loop.svg" alt="vibekit loop diagram" width="800"/>
</p>

---

## What's installed

| Location | What |
|----------|------|
| `~/.claude/commands/` | 7 slash commands (`/vb-setup`, `/vb-simulate`, `/vb-build`, `/vb-launch`, `/vb-review`, `/vb-pitch`, `/vb-daemon`) |
| `~/.claude/hooks/session-start.sh` | Shows issue dashboard on every Claude session start |
| `~/.claude/hooks/session-stop.sh` | Posts session transcript + plan + prompt to GitHub Issues |
| `~/.vibekit/daemon.sh` | Autonomous polling daemon |
| `~/.claude/settings.json` | Wires hooks into Claude Code (merges with existing settings) |

Per-project state lives in `.vibekit/` (gitignored scratch files) and GitHub Issues.

---

## What each command does

**`/vb-setup`** — one-time project bootstrap.

- Scans codebase and generates `PRODUCT.md` (your product spec — Claude reads this before every task)
- Creates GitHub labels: `bug`, `arch`, `carry`, `cycle`, `vibekit`, `highlight`, `critical`, `high`, `medium`, `low`
- Scaffolds `CLAUDE.md`, `Makefile`, structured logging (OTel/pino), RFC 9457 error handling
- Generates dev login shortcuts for Playwright
- Creates Highlights Index issue (tracks positive signals across cycles)
- Sets up GitHub Projects board, milestones, CI workflow

**`/vb-simulate`** — the core bug-finding loop. Runs indefinitely.

- Generates real customer personas from your product spec
- Runs Playwright journeys for each persona
- Fixes every bug inline, commits to `develop`
- Creates GitHub Issues for architectural gaps
- Audits every page on 9 UX dimensions + Core Web Vitals
- Updates Kanban board, milestones, and Highlights Index automatically

**`/vb-build`** — the autonomous workhorse. One approval, then hands-off.

- Default: full loop — build → test → simulate → watch → repeat
- Picks up issues labeled `vibekit` (create from GitHub, phone, anywhere)
- Auto-triages unlabeled issues (routes to `arch`, `bug`, or `carry`)
- Read → implement → Playwright verify → commit → close — per issue
- `--once` builds all open issues once then exits (used by daemon)
- `--issue N` implements a single issue
- Auto-triggers `/vb-launch` when zero open bugs remain

**`/vb-launch`** — ships when quality gates pass.

- Blocks on: open critical/high bugs, failing tests, UX score < 7/10, missing GTM docs
- Auto-increments version, generates release notes, creates GitHub release
- Closes milestone, opens next, merges `develop` → `main`

**`/vb-review`** — deep code review + test generation.

- Security (OWASP Top 10), code quality, deps health, accessibility — outputs GitHub Issues
- `--test` generates unit/integration/e2e tests
- `--fix` auto-fixes quality and UI findings
- `--pr N` scopes to a single PR

**`/vb-pitch`** — analytics and documentation.

- `--status` project health at a glance
- `--metrics` trend analysis across cycles
- `--sales` / `--dev` / `--investor` generates GTM and technical docs from real data

**`/vb-daemon`** — autonomous background loop.

- `install` — registers with launchd (macOS) or cron (Linux), polls every 3 minutes
- `uninstall` / `start` / `stop` / `status` / `logs`
- Survives reboots. No Claude session needed.

---

## Full audit trail

Every session is captured automatically.

| Signal | Where it lands |
|--------|---------------|
| Bugs found and fixed | `[Bug]` issues — closed with commit SHA |
| Architectural gaps | `[Arch]` issues — on Kanban board |
| Simulation cycles | `[Sim] Cycle N` parent issues |
| Session transcripts | Posted to open cycle issue on session end |
| Plans (plan-mode) | Attached to touched issues as collapsible blocks |
| User prompts | Posted as comments to touched issues |
| Daemon runs | Summarized as cycle issue comments |
| Release progress | GitHub milestones + releases |

---

## Works with any web app

Next.js, React/Vite, Django, Rails, Laravel — anything with a browser UI and a GitHub remote.

---

MIT · [ZySec AI](https://zysec.ai) · [hello@zysec.ai](mailto:hello@zysec.ai) · [Issues](https://github.com/ZySec-AI/vibekit/issues)
