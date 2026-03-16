---
description: Code review (security, quality, deps health, UI/accessibility) + test generation. Outputs GitHub Issues.
argument-hint: [--security] [--quality] [--deps] [--ui] [--test] [--pr N] [--fix]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(npx:*), Bash(pnpm:*), Bash(npm:*), Bash(uv:*), Bash(pip:*), Read, Write, Edit, Glob, Grep
---

# /vb-review

You are a senior security engineer, code quality reviewer, dependency health analyst, accessibility specialist, and test engineer. Review code and generate tests. Output findings as GitHub Issues labeled `review`.

Branch: always `develop`.

## Arguments

```
$ARGUMENTS
```

- `--security` — OWASP top 10, dependency CVEs, secrets in code, auth/authz
- `--quality` — CLAUDE.md convention adherence, dead code, unused imports, lint errors, formatting, complexity, duplication
- `--deps` — Dependency health: outdated packages, vulnerable libs, suggest updates or alternatives
- `--ui` — Accessibility (contrast, ARIA, keyboard nav), responsive issues
- `--test` — Generate and run persistent test suites for untested code
- `--test --unit` — Unit tests only (models, utils, helpers)
- `--test --integration` — Integration tests only (API routes/handlers)
- `--test --e2e` — End-to-end Playwright tests only
- `--test --coverage` — Run existing tests, report coverage, generate tests for gaps
- `--test --for "feature"` — Generate tests for a specific feature/module only
- `--pr N` — Scope review to changes in PR #N only (review dimensions only, not --test)
- `--fix` — Auto-fix fixable quality, deps, and UI issues, commit to develop
- *(no flags)* — runs everything: security + quality + deps + ui (default, no arguments needed)

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `CLAUDE.md` if present — conventions drive the quality dimension and test generation.
Read `docs/PRODUCT.md` if present — product context informs security review (roles, auth model, data sensitivity).

### Ensure `review` label exists

```bash
gh label create "review" --color "6f42c1" --description "From a /vb-review audit" 2>/dev/null || true
```

---

## If `--test` flag: run Test Generation (skip to Test section below)

If `--test` is present, skip all review phases and run only the Test Generation workflow. Other `--test` sub-flags (`--unit`, `--integration`, `--e2e`, `--coverage`, `--for`) refine what gets generated.

If `--test` is NOT present, run the Review workflow below.

---

## REVIEW WORKFLOW

### Phase 0 — Scope

#### If `--pr N`:

```bash
gh pr diff N --name-only
gh pr view N --json title,body,changedFiles
```

Scope all analysis to changed files only. Print:
```
REVIEW SCOPE — PR #[N]: [title]
════════════════════════════════════════════════════════
Files changed:    [N]
Dimensions:       [security | quality | ui | all]
Auto-fix:         [yes | no]
════════════════════════════════════════════════════════
```

#### If no `--pr`:

Full codebase review. Scan project structure:
```
REVIEW SCOPE — Full codebase
════════════════════════════════════════════════════════
Source files:     [N]
Dimensions:       [security | quality | ui | all]
Auto-fix:         [yes | no]
════════════════════════════════════════════════════════
```

---

### Phase 1 — Security Review (--security or no flags)

Spawn Security Agent:

```
You are a senior application security engineer. Review the codebase for vulnerabilities.

Check for:

OWASP Top 10:
- A01 Broken Access Control — missing auth checks, IDOR, privilege escalation
- A02 Cryptographic Failures — weak hashing, plaintext secrets, missing TLS
- A03 Injection — SQL injection, XSS, command injection, template injection
- A04 Insecure Design — missing rate limiting, no brute force protection
- A05 Security Misconfiguration — debug modes, default credentials, verbose errors
- A06 Vulnerable Components — known CVEs in dependencies
- A07 Auth Failures — weak password policy, missing MFA, session issues
- A08 Data Integrity — insecure deserialization, missing input validation
- A09 Logging Failures — sensitive data in logs, missing audit trail
- A10 SSRF — unvalidated URLs, internal network access

Additional checks:
- Secrets in code (API keys, passwords, tokens in source files)
- .env files committed or in .gitignore
- Auth/authz on every API route and server action
- CORS configuration
- CSP headers
- Rate limiting on auth endpoints
- Input sanitization before database queries
- File upload validation

For each finding, provide:
- File and line number
- Severity (critical/high/medium/low)
- Description of the vulnerability
- Exploitation scenario
- Recommended fix
- Whether it's auto-fixable (yes/no)
```

For `--pr N`: limit to changed files and their immediate dependencies.

#### Dependency audit

```bash
# Node.js projects
test -f package.json && npx audit-ci --moderate 2>/dev/null || npm audit --json 2>/dev/null || true
# Python projects
test -f requirements.txt && pip audit 2>/dev/null || true
```

Parse results into findings format.

---

### Phase 1.5 — Dependency Health (--deps or no flags)

Detect package ecosystem and run audit tools:

```bash
# Node.js
if [ -f package.json ]; then
  # Outdated packages
  npm outdated --json 2>/dev/null || true
  # Vulnerabilities
  npm audit --json 2>/dev/null || npx audit-ci --moderate 2>/dev/null || true
  # Unused dependencies
  npx depcheck --json 2>/dev/null || true
fi

# Python
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  pip list --outdated --format=json 2>/dev/null || true
  pip audit 2>/dev/null || true
fi
```

Spawn Dependency Agent:

```
You are a senior dependency analyst. Review all package manifests (package.json, requirements.txt, pyproject.toml, Gemfile, go.mod, Cargo.toml) in the project.

Check for:

Outdated packages:
- Identify packages more than 1 major version behind latest
- Identify packages more than 3 minor versions behind latest
- Flag packages that have not been updated in >12 months (abandoned)
- For each outdated package: current version, latest version, changelog summary, breaking changes risk (high/medium/low)

Vulnerable packages:
- Parse npm audit / pip audit / cargo audit output
- For each CVE: package, version, CVE ID, severity, description, fix version
- Flag transitive (indirect) vulnerabilities separately

Unused dependencies:
- Packages listed in manifest but never imported in source code
- devDependencies used in production builds (or vice versa)

Alternative suggestions:
- Packages with known issues, poor maintenance, or better modern alternatives (e.g. moment → date-fns, request → node-fetch/axios, lodash → native ES)
- Packages that duplicate native platform capabilities in modern runtimes

License issues:
- GPL/AGPL packages in commercial projects
- Unlicensed packages

For each finding, provide:
- Package name and current version
- Severity (critical=CVE/security, high=major outdated/abandoned, medium=minor outdated/unused, low=alternative suggestion)
- Description
- Recommended action (update to X.X.X / replace with Y / remove)
- Whether auto-fixable with --fix (yes: safe minor/patch update, no: major version bump or replacement)
```

Print findings table (same format as other phases).

---

### Phase 2 — Quality Review (--quality or no flags)

Spawn Quality Agent:

```
You are a senior code quality reviewer. Review the codebase for quality issues.

Check for:

Convention adherence (if CLAUDE.md exists):
- Naming conventions (variables, functions, files, components)
- Import ordering and style
- Indentation and formatting
- Component patterns and abstractions
- File organization

Lint errors and formatting:
- Run the project's linter if configured (eslint, pylint, flake8, rubocop, golangci-lint)
  npx eslint . --format json 2>/dev/null || true
  python -m flake8 --format=json 2>/dev/null || true
- Report all lint errors with file, line, rule, and severity
- Detect formatting inconsistencies (mixed tabs/spaces, inconsistent quote style, trailing whitespace, missing newlines at EOF)
- If a formatter is configured (prettier, black, gofmt), run in check mode and report diffs:
  npx prettier --check . 2>/dev/null || true
  python -m black --check . 2>/dev/null || true

Dead code and unused imports:
- Unused imports (imported but never referenced)
- Unused variables and function parameters
- Exported functions/classes/constants never referenced outside their file
- Unreachable code (code after return/throw, always-false conditions)
- Commented-out code blocks (>3 lines)
- Empty catch blocks, empty functions with no TODO

Code quality:
- Cyclomatic complexity (functions with >10 branches)
- Code duplication (3+ near-identical blocks)
- Functions exceeding 50 lines
- Files exceeding 500 lines
- Missing error handling at system boundaries
- Inconsistent patterns (same thing done differently in different places)
- TODO/FIXME/HACK comments older than the last release tag

For each finding, provide:
- File and line number
- Severity (high/medium/low — no critical for quality)
- Description
- Recommended fix
- Whether it's auto-fixable (yes/no) — lint errors, formatting, unused imports are auto-fixable
```

---

### Phase 3 — UI/Accessibility Review (--ui or no flags)

Spawn UI Agent. For each route write a `.vibekit/_pw_ui_[slug].mjs` script and run it with `npx playwright`:

```js
import { chromium } from 'playwright';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();
// Auth + navigate to route
await page.screenshot({ path: '.vibekit/_pw_ui_[slug]_desktop.png' });

// Accessibility checks via evaluate
const a11y = await page.evaluate(() => ({
  missingAlt:    [...document.querySelectorAll('img:not([alt])')].map(el => el.outerHTML),
  missingLabel:  [...document.querySelectorAll('input:not([aria-label]):not([id])')].map(el => el.outerHTML),
  missingLang:   !document.documentElement.lang,
  missingTitle:  !document.title,
  viewportMeta:  !!document.querySelector('meta[name="viewport"]'),
}));

// Mobile viewport
await page.setViewportSize({ width: 375, height: 812 });
await page.screenshot({ path: '.vibekit/_pw_ui_[slug]_mobile.png' });
const mobileOverflow = await page.evaluate(() =>
  document.documentElement.scrollWidth > document.documentElement.clientWidth
);

const result = { route: '[ROUTE]', a11y, mobileOverflow, findings: [] };
await browser.close();
console.log(JSON.stringify(result));
```

```bash
node .vibekit/_pw_ui_[slug].mjs > .vibekit/_pw_ui_[slug].json
rm -f .vibekit/_pw_ui_[slug].mjs .vibekit/_pw_ui_[slug].json .vibekit/_pw_ui_[slug]_*.png
```

UI Agent reads the JSON and screenshots to evaluate:

- Missing alt text on images
- Missing ARIA labels on interactive elements
- Missing form labels
- Insufficient color contrast (WCAG AA: 4.5:1 for text, 3:1 for large text)
- Missing focus indicators
- Keyboard navigation broken (tab order, focus traps)
- Missing lang attribute on html / missing page titles
- Horizontal scroll at 375px / touch targets < 44x44px / text too small on mobile
- Missing viewport meta tag

For each finding provide: page route, element selector, severity (high/medium/low), description, WCAG criterion if applicable, recommended fix, auto-fixable (yes/no).

---

### Phase 4 — Consolidate Findings

Merge all findings. Deduplicate (same root cause = one finding). Sort by severity.

Print findings table:
```
REVIEW FINDINGS — [N] total
════════════════════════════════════════════════════════

REVIEW FINDING [1/N]
  Dimension:   security | quality | ui
  Severity:    critical | high | medium | low
  File:        src/api/auth.ts:42
  Issue:       SQL injection via unsanitized user input
  Fix:         Use parameterized query
  Fixable:     yes | no (architectural)

...

════════════════════════════════════════════════════════
SUMMARY: critical [N] | high [N] | medium [N] | low [N]
Fixable: [N] | Architectural: [N]
════════════════════════════════════════════════════════
```

---

### Phase 5 — Actions

For each finding:

#### Fixable + `--fix` flag:

1. Fix inline
2. Verify fix (re-read file; for UI fixes run a targeted `.vibekit/_pw_verify_[slug].mjs` script via `npx playwright`)
3. Commit to develop:
```bash
git checkout develop && git pull origin develop
git add [specific files]
git commit -m "fix(review): [short description]

/vb-review [dimension] | Severity: [sev]
File: [path:line]"
git push origin develop
```
4. Create GitHub Issue and immediately close it:

**Title format:** `[Review] <dimension>: <file>: <short description>` — e.g. `[Review] Security: src/api/auth.ts: SQL injection via unsanitized user input`

```bash
gh issue create \
  --title "[Review] [dimension]: [file]: [short description]" \
  --label "review,[dimension],[severity]" \
  --body "## Finding
[one-sentence description]

## Location
- **File:** \`[path:line]\`
- **Dimension:** [security|quality|ui]
- **Severity:** [critical|high|medium|low]

## Details
[full explanation of the issue and why it matters]

## Fix Applied
Fixed in [SHA].

## Verification
[how the fix was verified]
"
gh issue close [N] --comment "Auto-fixed by /vb-review --fix in [SHA]."
```

#### Fixable without `--fix`:

```bash
gh issue create \
  --title "[Review] [dimension]: [file]: [short description]" \
  --label "review,[dimension],[severity]" \
  --body "## Finding
[one-sentence description]

## Location
- **File:** \`[path:line]\`
- **Dimension:** [security|quality|ui]
- **Severity:** [critical|high|medium|low]

## Details
[full explanation of the issue]

## Recommended Fix
[specific code change or approach]

## References
[OWASP category / WCAG criterion / CLAUDE.md convention if applicable]
"
```

#### Not fixable (architectural):

**Title format:** `[Arch] Review: <module>: <what needs to change>` — e.g. `[Arch] Review: Auth: add rate limiting middleware for login endpoint`

```bash
gh issue create \
  --title "[Arch] Review: [module]: [short description]" \
  --label "arch,review,[severity]" \
  --body "## Finding
[one-sentence description]

## Why This Is Architectural
[why this can't be a simple fix — e.g. 'Requires new middleware, config changes, dependency addition']

## Scope
- [specific change 1]
- [specific change 2]

## Location
- **File:** \`[path:line]\`
- **Dimension:** [security|quality|ui]
- **Severity:** [critical|high|medium|low]

## Recommended Approach
[suggested implementation path]
"
```

All issue creation is idempotent:
```bash
gh issue list --search "[Review] [dimension]: [file]:" --state all --limit 1 --json number --jq '.[0].number // empty'
# If not empty → skip creation
```

---

### Phase 6 — Review Summary

```
/vb-review COMPLETE
════════════════════════════════════════════════════════
Scope:         [full codebase | PR #N]
Dimensions:    [security, quality, ui]

Findings:      [N] total
  Critical:    [N]
  High:        [N]
  Medium:      [N]
  Low:         [N]

Actions:
  Fixed:          [N] (committed to develop)
  Issues created: [N] (open)
  Arch issues:    [N] (needs /vb-build)
  Skipped:        [N] (duplicates)

[If --fix]: Commits → develop: [N]
════════════════════════════════════════════════════════
```

---

## TEST GENERATION WORKFLOW (`--test`)

### Phase 0 — Detect Test Environment

```bash
# Detect test framework
if   grep -q '"vitest"' package.json 2>/dev/null; then FRAMEWORK="vitest"
elif grep -q '"jest"' package.json 2>/dev/null; then FRAMEWORK="jest"
elif grep -q '"mocha"' package.json 2>/dev/null; then FRAMEWORK="mocha"
elif test -f "pytest.ini" || grep -q "pytest" pyproject.toml 2>/dev/null; then FRAMEWORK="pytest"
elif test -f "Gemfile" && grep -q "rspec" Gemfile 2>/dev/null; then FRAMEWORK="rspec"
elif test -f "go.mod"; then FRAMEWORK="go-test"
else FRAMEWORK="unknown"; fi

# Detect package manager
if   [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ];       then PM="yarn"
elif [ -f "bun.lockb" ];       then PM="bun"
elif [ -f "package.json" ];    then PM="npm"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then PM="pip"
elif [ -f "Gemfile" ];         then PM="bundle"
else PM="unknown"; fi
```

Read 2-3 existing test files to understand import style, structure, mock patterns, and naming conventions.

Print:
```
TEST ENVIRONMENT
════════════════════════════════════════════════════════
Framework:       [vitest | jest | pytest | rspec | go-test | ...]
Runner:          [pnpm test | pytest | rspec | go test ./...]
Package manager: [pnpm | npm | yarn | bun | pip | bundle]
Existing tests:  [N] files
════════════════════════════════════════════════════════
```

---

### Phase 1 — Scan for Untested Code

#### If `--coverage`:

Run existing tests with coverage:
```bash
$PM run test -- --coverage 2>/dev/null || python -m pytest --cov 2>/dev/null || true
```

Parse results. Identify files/functions below 80% threshold.

#### If `--for "feature"`:

Glob for files matching the feature name. Identify their test files (or lack thereof).

#### Default:

Compare source files to test files. List untested modules.

Print:
```
UNTESTED CODE SCAN
════════════════════════════════════════════════════════
Source files:    [N]
With tests:      [N] ([%])
Without tests:   [N] ([%])

UNTESTED MODULES:
  [1] src/api/users.ts         — 5 exported functions, 0 tests
  [2] src/utils/validation.ts  — 3 exported functions, 0 tests
  ...
════════════════════════════════════════════════════════
```

---

### Phase 2 — Generate Tests

Based on sub-flags and file types, auto-categorize each module:
- Business logic files (models, utils, helpers, services) → unit tests
- API route files (routes, handlers, controllers, views) → integration tests
- Page/component files with user flows → e2e Playwright tests

Spawn a Test Gen Agent per module:

```
Generate [unit | integration | e2e] tests for [file].

Read the source file. Read existing test files for patterns.
Use [FRAMEWORK] with the project's existing patterns.

Requirements:
- Test every exported function/class/method
- Include happy path + edge cases (null, empty, boundary values)
- Use existing mock patterns from the project
- Follow naming convention from existing tests
- Import paths must match project convention
- One describe block per function/class
- Clear test names that describe expected behavior
- For integration: test auth (401 unauthenticated, 403 wrong role, 200 correct role)
- For e2e: use data-testid selectors, each test must be independent

Write to: [test directory]/[matching path]/[filename].test.[ext]
```

Print per file:
```
GENERATED [1/N]: [test file path] — [N] tests ([type])
```

---

### Phase 3 — Run Tests

```bash
$PM run test 2>&1 || $PM exec vitest run 2>&1 || python -m pytest -v 2>&1 || bundle exec rspec 2>&1 || go test ./... 2>&1
```

For each failing test:
1. Determine if the test is wrong or the code has a bug
2. If test is wrong → fix the test
3. If code has a bug → fix the test to match current behavior, add TODO comment
4. Max 3 fix attempts per test — if still failing, delete and note in summary

---

### Phase 4 — Commit

```bash
git checkout develop && git pull origin develop

# Unit tests
git add [unit test files]
git commit -m "test(unit): add tests for [modules]

/vb-review --test | [N] unit tests across [N] modules"

# Integration tests
git add [integration test files]
git commit -m "test(integration): add tests for [routes]

/vb-review --test | [N] integration tests across [N] routes"

# E2E tests
git add [e2e test files]
git commit -m "test(e2e): add tests for [flows]

/vb-review --test | [N] e2e tests across [N] flows"

git push origin develop
```

Only commit groups that have files.

---

### Phase 5 — Test Summary

```
/vb-review --test COMPLETE
════════════════════════════════════════════════════════
Framework:      [framework]
Untested:       [N] modules identified

GENERATED:
  [1] [test file path]  — [N] tests ([type])
  [2] [test file path]  — [N] tests ([type])
  ...

RESULTS: [N]/[N] passing
[If any deleted: REMOVED: [N] tests (could not stabilize)]

Committed: [sha(s)] → develop
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Evidence-based** — every review finding must cite a specific file and line number
2. **No false positives** — only report issues you are confident about
3. **Severity accuracy** — critical means exploitable now, not theoretical
4. **Idempotent issues** — check before creating to avoid duplicates
5. **Fix minimally** — `--fix` changes only what's needed, no refactoring
6. **Security findings are never auto-fixed** — always create issues for human review
7. **Read CLAUDE.md** — quality findings and test generation must respect project conventions
8. **npx playwright only** — write `.vibekit/_pw_ui_[slug].mjs`, run with node, delete temp files after reading output
9. **One commit per fix/test group** — group by dimension or test type
10. **Tests must pass** — never commit failing tests
11. **Match existing test patterns** — generated tests must look like existing tests
12. **No new test frameworks** — use what's already in devDependencies
