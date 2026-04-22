# Anthropic cloud scanner — Managed Agents sessions.
#
# Requires:
#   ANTHROPIC_API_KEY                — loaded by the caller (setup.sh may source
#                                       a Doppler-cached env file before exec).
#   ANTHROPIC_BETA_HEADER (optional) — defaults to managed-agents-2025-09-25;
#                                       override if Anthropic bumps the beta.
#
# The endpoint shape returned by the Managed Agents beta has evolved; this
# scanner reads defensively (`// empty`) so field renames don't break it.
# If the API call fails, it logs a one-line diagnostic to stderr and returns
# cleanly — other sources continue to work.

scan_anthropic() {
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] || {
    echo "recent-sessions: skipping anthropic source — ANTHROPIC_API_KEY not set" >&2
    return 0
  }
  command -v curl &>/dev/null || { echo "recent-sessions: anthropic needs curl" >&2; return 0; }
  command -v jq   &>/dev/null || { echo "recent-sessions: anthropic needs jq"   >&2; return 0; }

  local beta="${ANTHROPIC_BETA_HEADER:-managed-agents-2025-09-25}"
  local base="${ANTHROPIC_API_BASE:-https://api.anthropic.com}"
  local limit="${ANTHROPIC_SESSION_LIMIT:-100}"

  local body http_code
  local response
  response=$(curl -sS -w '\n%{http_code}' \
      -H "x-api-key: ${ANTHROPIC_API_KEY}" \
      -H "anthropic-version: 2023-06-01" \
      -H "anthropic-beta: ${beta}" \
      "${base}/v1/sessions?limit=${limit}" 2>/dev/null) || {
    echo "recent-sessions: anthropic request failed (network)" >&2
    return 0
  }
  http_code=$(printf '%s' "$response" | tail -n1)
  body=$(printf '%s' "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    local err
    err=$(printf '%s' "$body" | jq -r '.error.message // .error // empty' 2>/dev/null)
    echo "recent-sessions: anthropic returned HTTP ${http_code}${err:+ — $err}" >&2
    return 0
  fi

  # Iterate sessions defensively — the response key has varied between betas.
  printf '%s' "$body" \
    | jq -c '(.sessions // .data // [])[]' 2>/dev/null \
    | while IFS= read -r sess; do
        local id updated agent
        id=$(printf '%s' "$sess"     | jq -r '.id // .session_id // empty')
        updated=$(printf '%s' "$sess" | jq -r '.updated_at // .last_used_at // .created_at // empty')
        agent=$(printf '%s' "$sess"   | jq -r '.agent_id // .agent // .name // "session"')
        [[ -n "$id" && -n "$updated" ]] || continue
        local mtime
        mtime=$(iso_to_epoch "$updated")
        emit "$mtime" "anthropic" "$agent" "$id" "anthropic session $id (beta $beta)"
      done
}
