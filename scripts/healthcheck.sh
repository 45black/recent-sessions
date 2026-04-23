#!/bin/bash
# healthcheck.sh — probe the configured Anthropic Managed Agents beta header
# so the skill can warn early when Anthropic rotates beta labels.
#
# Exit 0 if the configured beta is still accepted (HTTP 200).
# Exit 1 otherwise; the server's error body usually quotes the current
# label so the user can update ANTHROPIC_BETA_HEADER in config.env.
#
# Usage: bash scripts/healthcheck.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SKILL_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "healthcheck: config.env not found — run scripts/setup.sh first" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [[ "${SOURCE_ANTHROPIC:-0}" != "1" ]]; then
  echo "healthcheck: anthropic source not enabled in config.env (SOURCE_ANTHROPIC=0) — nothing to check"
  exit 0
fi

if [[ -n "${ANTHROPIC_SECRETS_FILE:-}" && -f "$ANTHROPIC_SECRETS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ANTHROPIC_SECRETS_FILE"
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "healthcheck: ANTHROPIC_API_KEY not set (check ANTHROPIC_SECRETS_FILE in config.env)" >&2
  exit 1
fi

command -v curl >/dev/null 2>&1 || { echo "healthcheck: curl not available" >&2; exit 1; }

BETA="${ANTHROPIC_BETA_HEADER:-managed-agents-2026-04-01}"
BASE="${ANTHROPIC_API_BASE:-https://api.anthropic.com}"

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

http_code=$(curl -sS -o "$body_file" -w '%{http_code}' \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: ${BETA}" \
  "${BASE}/v1/sessions" 2>/dev/null) || {
  echo "healthcheck: request to ${BASE}/v1/sessions failed (network?)" >&2
  exit 1
}

if [[ "$http_code" == "200" ]]; then
  echo "ok: ${BETA} still valid on /v1/sessions (HTTP 200)"
  exit 0
fi

echo "DRIFT: HTTP ${http_code} for beta=${BETA}" >&2
if command -v jq >/dev/null 2>&1; then
  msg=$(jq -r '.error.message // empty' < "$body_file" 2>/dev/null || true)
else
  msg=""
fi
if [[ -n "$msg" ]]; then
  echo "server: ${msg}" >&2
  # Extract the backtick-quoted replacement label if present — Anthropic's
  # error text uses the form: "add `managed-agents-YYYY-MM-DD` to the ..."
  if [[ "$msg" =~ \`([a-z-]+[0-9-]+)\` ]]; then
    echo "suggested ANTHROPIC_BETA_HEADER=\"${BASH_REMATCH[1]}\"" >&2
    echo "update ${CONFIG_FILE} and re-run this check" >&2
  fi
else
  sed -e 's/^/  body: /' "$body_file" >&2
fi

exit 1
