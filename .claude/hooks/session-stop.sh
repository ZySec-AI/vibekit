#!/bin/bash
# vibekit session transcript — zero LLM calls, pure jq + regex pipeline
set -euo pipefail

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
COMMITS=$(jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content[]? | select(.type=="text") | .text' "$SAFE_JSONL" 2>/dev/null | grep -oE '\b[0-9a-f]{7,12}\b' | sort -u | tr '\n' ' ')
TOUCHED_ISSUES=$(grep -oE '(#[0-9]+|issues/[0-9]+)' "$TRANSCRIPT" | grep -oE '[0-9]+' | sort -u)

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

  ISSUE_TURNS=$(grep -n "#${ISSUE_NUM}\b" "$TRANSCRIPT" | cut -d: -f1 | while read -r LINE_NUM; do
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

rm -f "$TRANSCRIPT" "$SAFE_JSONL"
