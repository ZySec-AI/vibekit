#!/bin/bash
# vibekit session transcript — zero LLM calls, pure jq + regex pipeline
set -uo pipefail

VIBEKIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.vibekit"
[ -d "$VIBEKIT_DIR" ] || exit 0

# Load repo context
[ -f "$VIBEKIT_DIR/repo.env" ] || exit 0
source "$VIBEKIT_DIR/repo.env"

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
  -e 's/(password|passwd|secret|token|api_?key|auth)[[:space:]]*[:=][[:space:]]*["'"'"']?[^"'"'"',\n}{]{6,}/\1=[REDACTED]/gi' \
  -e 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[IP_REDACTED]/g' \
  "$LATEST_JSONL" > "$SAFE_JSONL"

# Step 3 — extract full conversation transcript (from sanitized file)
TRANSCRIPT="$VIBEKIT_DIR/session-transcript-$$.txt"
SESSION_DATE="$(date '+%Y-%m-%d %H:%M')"

jq -r '
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
COMMITS=$(jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content[]? | select(.type=="text") | .text' "$SAFE_JSONL" 2>/dev/null | grep -oE '\b[0-9a-f]{7,12}\b' | sort -u | tr '\n' ' ' || true)
TOUCHED_ISSUES=$(grep -oE '(#[0-9]+|issues/[0-9]+)' "$TRANSCRIPT" | grep -oE '[0-9]+' | sort -u || true)

HEADER="## vibekit session — ${REPO_NAME} — ${SESSION_DATE}
Tool calls: ${TOOL_COUNT} | Commits: ${COMMITS:-none}
Issues touched: $(echo "$TOUCHED_ISSUES" | tr '\n' ' ' | sed 's/ $//')"

# Step 6 — post full transcript to cycle issue (chunked at ~400 lines)
CYCLE_ISSUE=$(gh issue list --label "cycle" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
if [ -n "$CYCLE_ISSUE" ]; then
  CHUNK_SIZE=400
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

  echo "Session transcript posted to cycle issue #${CYCLE_ISSUE}"
fi

# Step 7 — post per-issue comments with turns mentioning that issue
for ISSUE_NUM in $TOUCHED_ISSUES; do
  [ "$ISSUE_NUM" = "$CYCLE_ISSUE" ] && continue

  ISSUE_TURNS=$(grep -n "#${ISSUE_NUM}\b" "$TRANSCRIPT" 2>/dev/null | cut -d: -f1 | while read -r LINE_NUM; do
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

# Step 8 — attach plan to touched issues and cycle issue
LAST_PLAN_POSTED="$VIBEKIT_DIR/last-plan-posted.txt"
PLAN_FILE=$(find "$HOME/.claude/plans" -name "*.md" -newer "$SAFE_JSONL" -not -name "*-agent-*" 2>/dev/null | head -1)
# Fallback: most recent plan modified in last 4 hours
if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(find "$HOME/.claude/plans" -name "*.md" -not -name "*-agent-*" -mmin -240 2>/dev/null | sort | tail -1)
fi

# Idempotency: skip if this plan was already posted this session
if [ -n "$PLAN_FILE" ] && [ -f "$LAST_PLAN_POSTED" ]; then
  LAST_POSTED=$(cat "$LAST_PLAN_POSTED" 2>/dev/null || true)
  [ "$LAST_POSTED" = "$PLAN_FILE" ] && PLAN_FILE=""
fi

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  PLAN_NAME=$(basename "$PLAN_FILE" .md)
  PLAN_BODY=$(cat "$PLAN_FILE")
  PLAN_COMMENT="<details><summary>Plan: ${PLAN_NAME} — ${SESSION_DATE}</summary>

${PLAN_BODY}
</details>"

  # Post to cycle issue
  if [ -n "$CYCLE_ISSUE" ]; then
    gh issue comment "$CYCLE_ISSUE" --body "## Session Plan

${PLAN_COMMENT}" 2>/dev/null || true
  fi

  # Post to each touched issue
  for ISSUE_NUM in $TOUCHED_ISSUES; do
    [ "$ISSUE_NUM" = "$CYCLE_ISSUE" ] && continue
    gh issue comment "$ISSUE_NUM" --body "## Plan used in this session

${PLAN_COMMENT}" 2>/dev/null || true
  done

  echo "$PLAN_FILE" > "$LAST_PLAN_POSTED"
  echo "Plan '${PLAN_NAME}' attached to issues: ${CYCLE_ISSUE} ${TOUCHED_ISSUES}"
fi

# Step 9 — post user prompt as comment to touched issues
# Primary: last-prompt.txt written by session-start hook
# Fallback: first **User:** line from transcript
FIRST_USER_PROMPT=""
if [ -f "$VIBEKIT_DIR/last-prompt.txt" ]; then
  FIRST_USER_PROMPT=$(cat "$VIBEKIT_DIR/last-prompt.txt" | head -5 | tr '\n' ' ' || true)
fi
if [ -z "$FIRST_USER_PROMPT" ]; then
  FIRST_USER_PROMPT=$(grep '^\*\*User:\*\*' "$TRANSCRIPT" | head -1 | sed 's/^\*\*User:\*\* //' || true)
fi
if [ -n "$FIRST_USER_PROMPT" ]; then
  PROMPT_BODY="## User prompt — ${SESSION_DATE}

> ${FIRST_USER_PROMPT}"

  for ISSUE_NUM in $TOUCHED_ISSUES; do
    gh issue comment "$ISSUE_NUM" --body "$PROMPT_BODY" 2>/dev/null || true
  done

  if [ -n "$CYCLE_ISSUE" ]; then
    if ! echo "$TOUCHED_ISSUES" | grep -q "^${CYCLE_ISSUE}$" 2>/dev/null; then
      gh issue comment "$CYCLE_ISSUE" --body "$PROMPT_BODY" 2>/dev/null || true
    fi
  fi
fi

rm -f "$TRANSCRIPT" "$SAFE_JSONL"
