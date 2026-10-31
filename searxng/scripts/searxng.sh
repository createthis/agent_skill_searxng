#!/usr/bin/env bash
# searxng.sh — query a SearXNG instance and print the JSON API response to stdout.
# Zero dependencies beyond bash + curl. The instance endpoint is resolved at
# runtime; see the usage text for the resolution order.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: searxng.sh [options] "<search query>"

Options:
  --endpoint URL   One-off SearXNG base URL (overrides all other config).
  --timeout SECS   Request timeout in seconds (default: 30).
  -h, --help       Show this help.

Endpoint resolution (first match wins):
  1. --endpoint flag
  2. $SEARXNG_URL environment variable
  3. searxng.local in the skill directory (SEARXNG_URL=... or a bare URL)
  4. ~/.config/searxng-search/endpoint (same format)

The endpoint is the base URL of a SearXNG instance, e.g.
http://your-instance:8086 — no trailing slash, no /search path.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMEOUT=30
ENDPOINT=""
QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) ENDPOINT="${2:?--endpoint requires a URL}"; shift 2 ;;
    --timeout)  TIMEOUT="${2:?--timeout requires a number}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    -*)         echo "error: unknown option: $1" >&2; usage; exit 2 ;;
    *)
      if [[ -n "$QUERY" ]]; then
        echo "error: more than one query given" >&2; exit 2
      fi
      QUERY="$1"; shift ;;
  esac
done

# Read the first usable line from a config file; supports "SEARXNG_URL=..."
# or a bare URL, with comments.
read_endpoint_file() {
  local f="$1" line
  [[ -f "$f" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/^SEARXNG_URL[[:space:]]*[=:][[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ -n "$line" ]]; then
      printf '%s' "$line"
      return 0
    fi
  done < "$f"
  return 1
}

if [[ -z "$ENDPOINT" && -n "${SEARXNG_URL:-}" ]]; then
  ENDPOINT="$SEARXNG_URL"
fi
if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$(read_endpoint_file "$SKILL_DIR/searxng.local" || true)"
fi
if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$(read_endpoint_file "$SCRIPT_DIR/searxng.local" || true)"
fi
if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$(read_endpoint_file "${HOME:-/nonexistent}/.config/searxng-search/endpoint" || true)"
fi

if [[ -z "$ENDPOINT" ]]; then
  cat >&2 <<'EOF'
error: no SearXNG endpoint configured.

Configure one of (first match wins):
  1. pass --endpoint http://your-instance:8086
  2. export SEARXNG_URL=http://your-instance:8086
  3. cp searxng.example searxng.local  (next to this script, then edit)
  4. create ~/.config/searxng-search/endpoint

If you don't have a SearXNG instance yet, the easiest one is:
  docker run -d --name searxng -p 8086:8080 searxng/searxng
then point this script at http://localhost:8086.
EOF
  exit 3
fi

case "$ENDPOINT" in
  http://*|https://*) ;;
  *) echo "error: endpoint must be an http(s) URL, got: $ENDPOINT" >&2; exit 2 ;;
esac
ENDPOINT="${ENDPOINT%/}"

if [[ -z "$QUERY" ]]; then
  usage
  exit 2
fi

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

if ! HTTP_CODE="$(curl -sS -G -o "$BODY" -w '%{http_code}' \
    --max-time "$TIMEOUT" \
    -A 'agent-skill-searxng/1.0' \
    "$ENDPOINT/search" \
    --data-urlencode "q=$QUERY" \
    --data-urlencode "format=json" 2>&1)"; then
  echo "error: request to $ENDPOINT failed (network unreachable, instance down, or timeout after ${TIMEOUT}s): $HTTP_CODE" >&2
  exit 4
fi

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "error: SearXNG at $ENDPOINT returned HTTP $HTTP_CODE" >&2
  head -c 500 "$BODY" >&2
  echo >&2
  exit 4
fi

if ! head -c 1 "$BODY" | grep -q '{'; then
  echo "error: response from $ENDPOINT is not JSON — is it really a SearXNG instance?" >&2
  head -c 500 "$BODY" >&2
  echo >&2
  exit 4
fi

cat "$BODY"
