---
description: Generate and maintain persistent test suites. Scans for untested code, generates tests, runs them.
argument-hint: [--unit] [--integration] [--e2e] [--for "feature"] [--coverage]
model: sonnet
allowed-tools: Agent, Bash(gh:*), Bash(git:*), Bash(pnpm:*), Bash(npm:*), Bash(yarn:*), Bash(bun:*), Bash(npx:*), Bash(python:*), Read, Write, Edit, Glob, Grep, mcp__playwright__*
---

# /vibekit-test

You are a senior test engineer. Scan the codebase, identify untested code paths, generate test files using the project's existing test framework, run them, and commit passing tests.

Branch: always `develop`.

## Arguments

```
$ARGUMENTS
```

- `--unit` — Unit tests for business logic (models, utils, helpers)
- `--integration` — Integration tests for API routes/handlers
- `--e2e` — End-to-end Playwright test files (persistent, not ephemeral)
- `--for "feature"` — Generate tests for a specific feature/module only
- `--coverage` — Run existing tests, report coverage, generate tests for gaps
- *(no flags)* — scans for untested code, generates all types

---

## Prerequisites

```bash
gh auth status || { echo "ERROR: gh auth login first."; exit 1; }
git remote get-url origin || { echo "ERROR: No git remote."; exit 1; }
```

Read `CLAUDE.md` if present — follow test conventions and patterns.

---

## Phase 0 — Detect Test Environment

### Detect test framework

```bash
# Node.js
if   grep -q '"vitest"' package.json 2>/dev/null; then FRAMEWORK="vitest"
elif grep -q '"jest"' package.json 2>/dev/null; then FRAMEWORK="jest"
elif grep -q '"mocha"' package.json 2>/dev/null; then FRAMEWORK="mocha"
# Python
elif test -f "pytest.ini" || test -f "pyproject.toml" && grep -q "pytest" pyproject.toml 2>/dev/null; then FRAMEWORK="pytest"
elif test -f "setup.cfg" && grep -q "unittest" setup.cfg 2>/dev/null; then FRAMEWORK="unittest"
# Ruby
elif test -f "Gemfile" && grep -q "rspec" Gemfile 2>/dev/null; then FRAMEWORK="rspec"
# Go
elif test -f "go.mod"; then FRAMEWORK="go-test"
else FRAMEWORK="unknown"; fi
```

If FRAMEWORK is "unknown": scan for test files to infer framework. If still unknown: ask user what framework to use.

### Detect test directory

```bash
# Look for existing test directories
for dir in __tests__ tests test spec e2e cypress playwright; do
  test -d "$dir" && echo "$dir"
done
# Also check for co-located tests
find . -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" 2>/dev/null | head -5
```

### Detect test runner command

```bash
# From package.json scripts
grep -E '"test"' package.json 2>/dev/null
grep -E '"test:unit"' package.json 2>/dev/null
grep -E '"test:e2e"' package.json 2>/dev/null
```

### Detect package manager

```bash
if   [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ];       then PM="yarn"
elif [ -f "bun.lockb" ];       then PM="bun"
elif [ -f "package.json" ];    then PM="npm"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then PM="pip"
elif [ -f "Gemfile" ];         then PM="bundle"
else PM="unknown"; fi
```

### Read existing test patterns

Read 2-3 existing test files to understand:
- Import style (relative vs alias)
- Test structure (describe/it, test(), def test_)
- Mocking patterns (jest.mock, vi.mock, unittest.mock, factory_bot)
- Setup/teardown patterns
- Assertion style
- File naming convention

Print:
```
TEST ENVIRONMENT
════════════════════════════════════════════════════════
Framework:      [vitest | jest | pytest | rspec | go-test | ...]
Test dir:       [path]
Runner:         [pnpm test | pytest | rspec | go test ./...]
Package manager: [pnpm | npm | yarn | bun | pip | bundle]
Existing tests: [N] files
Pattern:        [describe/it | test() | def test_ | ...]
════════════════════════════════════════════════════════
```

---

## Phase 1 — Scan for Untested Code

### If `--coverage` flag:

Run existing tests with coverage:
```bash
# vitest
$PM run test -- --coverage --reporter=json 2>/dev/null || true
# jest
$PM run test -- --coverage --json 2>/dev/null || true
# pytest
python -m pytest --cov --cov-report=json 2>/dev/null || true
```

Parse coverage report. Identify files/functions below threshold (default 80%).

### If `--for "feature"`:

Glob for files matching the feature name. Identify their test files (or lack thereof).

### Default (no flags):

Compare source files to test files:
1. List all source files (exclude node_modules, dist, build, .next, __pycache__, vendor)
2. For each source file, check if a corresponding test file exists
3. For files with tests, check if all exported functions/classes have test cases
4. Build untested modules list

Print:
```
UNTESTED CODE SCAN
════════════════════════════════════════════════════════
Source files:     [N]
With tests:       [N] ([%])
Without tests:    [N] ([%])
[If --coverage: Coverage: [N]%]

UNTESTED MODULES:
  [1] src/api/users.ts          — 5 exported functions, 0 tests
  [2] src/utils/validation.ts   — 3 exported functions, 0 tests
  [3] src/models/tenant.ts      — 2 classes, 0 tests
  ...
════════════════════════════════════════════════════════
```

---

## Phase 2 — Generate Tests

### Determine test types

Based on flags and file types:
- `--unit` or business logic files (models, utils, helpers, services) → unit tests
- `--integration` or API route files (routes, handlers, controllers, views) → integration tests
- `--e2e` or page/component files with user flows → Playwright e2e tests
- No flags → auto-categorize each untested module

### Generate unit tests

For each untested business logic module, spawn a Test Gen Agent:

```
Generate unit tests for [file].

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

Write to: [test directory]/[matching path]/[filename].test.[ext]
```

### Generate integration tests

For each untested API route/handler:

```
Generate integration tests for [route file].

Read the source file and any middleware it uses.
Use [FRAMEWORK] with the project's existing patterns.

Requirements:
- Test each HTTP method (GET, POST, PUT, DELETE)
- Test auth: unauthenticated → 401, wrong role → 403, correct role → 200
- Test validation: missing fields, invalid types, boundary values
- Test success and error responses
- Mock external dependencies (DB, external APIs)
- Follow existing integration test patterns

Write to: [test directory]/[matching path]/[filename].test.[ext]
```

### Generate e2e tests

For each untested user flow:

```
Generate Playwright e2e test for [page/flow].

Read the page component and its route.
Use Playwright test runner with project conventions.

Requirements:
- Test the primary user flow for this page
- Test form submissions with valid and invalid data
- Test navigation between related pages
- Test responsive behavior (desktop + mobile viewport)
- Use data-testid selectors where available, fall back to role-based selectors
- Include setup (login) and teardown
- Each test must be independent (no test-order dependency)

Write to: [e2e directory]/[flow-name].spec.[ext]
```

Print after each file:
```
GENERATED [1/N]: [test file path] — [N] tests ([unit | integration | e2e])
```

---

## Phase 3 — Run Tests

Run the full test suite:

```bash
# Run all tests
$PM run test 2>&1 || $PM test 2>&1
```

If specific test runner:
```bash
# vitest
$PM exec vitest run 2>&1
# jest
$PM exec jest 2>&1
# pytest
python -m pytest -v 2>&1
# rspec
bundle exec rspec 2>&1
# go
go test ./... -v 2>&1
```

### Handle failures

For each failing test:
1. Read the error message and failing assertion
2. Determine if the test is wrong or the code has a bug
3. If test is wrong → fix the test (wrong assertion, wrong mock, wrong import)
4. If code has a bug → fix the test to match current behavior, add a TODO comment noting the potential bug
5. Re-run to verify

Max 3 fix attempts per test. If still failing → delete the test, note it in summary.

---

## Phase 4 — Commit

```bash
git checkout develop
git pull origin develop
```

Commit in groups by test type:

```bash
# Unit tests
git add [unit test files]
git commit -m "test(unit): add tests for [modules]

/vibekit-test — [N] unit tests across [N] modules
Framework: [framework]"

# Integration tests
git add [integration test files]
git commit -m "test(integration): add tests for [routes]

/vibekit-test — [N] integration tests across [N] routes
Framework: [framework]"

# E2E tests
git add [e2e test files]
git commit -m "test(e2e): add tests for [flows]

/vibekit-test — [N] e2e tests across [N] flows
Framework: playwright"

git push origin develop
```

Only commit groups that have files. Skip empty groups.

---

## Phase 5 — Summary

```
TEST GENERATION — [repo name]
════════════════════════════════════════════════════════
  Framework:      [framework]
  Test dir:       [path]
  Existing tests: [N] files
  Untested:       [N] modules identified

  GENERATED:
    [1] [test file path]     — [N] tests ([type])
    [2] [test file path]     — [N] tests ([type])
    [3] [test file path]     — [N] tests ([type])
    ...

  RESULTS: [N]/[N] passing
  [If any deleted: REMOVED: [N] tests (could not stabilize)]

  Committed: [sha(s)] → develop
════════════════════════════════════════════════════════
```

---

## Ground Rules

1. **Match existing patterns** — generated tests must look like existing tests in the project
2. **No new test frameworks** — use what's already in devDependencies
3. **Persistent tests** — all tests are committed files, not ephemeral
4. **Tests must pass** — never commit failing tests
5. **No over-mocking** — mock external boundaries, not internal logic
6. **Clear names** — test names describe expected behavior, not implementation
7. **One commit per test type** — unit, integration, e2e as separate commits
8. **Read before generating** — always read the source file and existing test patterns first
9. **No test-only dependencies** — unless the project already has them (e.g., @testing-library)
10. **Follow CLAUDE.md** — if it specifies test conventions, follow them exactly
