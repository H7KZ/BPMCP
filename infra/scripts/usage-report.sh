#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# usage-report.sh {daily|weekly|monthly} [environment]
#
# Queries the (loopback) Prometheus and posts a MCP usage summary to Discord.
# NON-IDENTIFYING metrics only — volume / reliability / popularity. No unique
# users, no IPs (see CONTEXT.md "Usage" + docs/adr/0002-monitoring-topology.md).
#
# Run by ops-usage-report@{daily,weekly,monthly}.timer. CONFIG: /etc/ops.env
# ==============================================================================

# Optional external config (plain KEY=VALUE, not code)
[ -f /etc/ops.env ] && { set -a; . /etc/ops.env; set +a; }

PERIOD="${1:-daily}"
ENV_LABEL="${2:-production}"
PROM_URL="${PROM_URL:-http://127.0.0.1:9090}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

case "$PERIOD" in
  daily)   RANGE=24h; TITLE="Daily";   TOPN=3;  COLOR=3447003  ;;
  weekly)  RANGE=7d;  TITLE="Weekly";  TOPN=5;  COLOR=3066993  ;;
  monthly) RANGE=30d; TITLE="Monthly"; TOPN=10; COLOR=10181046 ;;
  *) echo "usage: $0 {daily|weekly|monthly} [environment]" >&2; exit 2 ;;
esac

command -v jq   >/dev/null 2>&1 || { echo "jq missing";   exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl missing"; exit 1; }

# promq <PromQL> -> first scalar result (or 0)
promq() {
  curl -fsG "$PROM_URL/api/v1/query" --data-urlencode "query=$1" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // "0"'
}

E="env=\"$ENV_LABEL\""
TOTAL=$(promq  "round(sum(increase(mcp_tool_calls_total{$E}[$RANGE])))")
ERRORS=$(promq "round(sum(increase(mcp_tool_calls_total{$E,status=\"error\"}[$RANGE])))")
ERRRATE=$(promq "sum(increase(mcp_tool_calls_total{$E,status=\"error\"}[$RANGE])) / clamp_min(sum(increase(mcp_tool_calls_total{$E}[$RANGE])),1) * 100")
P95=$(promq    "round(1000 * histogram_quantile(0.95, sum by (le) (rate(mcp_tool_call_duration_seconds_bucket{$E}[$RANGE]))))")

ERRRATE_FMT=$(printf '%.2f' "${ERRRATE:-0}" 2>/dev/null || echo "0")

TOP=$(curl -fsG "$PROM_URL/api/v1/query" \
  --data-urlencode "query=topk($TOPN, round(sum by (tool) (increase(mcp_tool_calls_total{$E}[$RANGE]))))" 2>/dev/null \
  | jq -r --argjson total "${TOTAL:-0}" '
      (.data.result // [])
      | map({tool: (.metric.tool // "?"), n: (.value[1] | tonumber)})
      | sort_by(-.n) | .[]
      | "• `\(.tool)` — \(.n)" + (if $total > 0 then " (\((.n / $total * 100) | floor)%)" else "" end)')
[ -z "$TOP" ] && TOP="• (no calls in window)"

DESC=$(printf 'Window: last %s\n\n**Total calls:** %s\n**Errors:** %s (%s%%)\n**p95 latency:** %s ms\n\n**Top tools:**\n%s' \
  "$RANGE" "${TOTAL:-0}" "${ERRORS:-0}" "$ERRRATE_FMT" "${P95:-0}" "$TOP")

if [ -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "DISCORD_WEBHOOK_URL not set — printing report instead:"
  echo "$DESC"
  exit 0
fi

payload=$(jq -n \
  --arg t "📊 MCP ${TITLE} usage — ${ENV_LABEL}" \
  --arg d "${DESC:0:3900}" \
  --argjson c "$COLOR" \
  --arg h "$(hostname)" \
  '{embeds:[{title:$t,description:$d,color:$c,footer:{text:$h},timestamp:(now|todate)}]}')

curl -fsS --max-time 15 -X POST -H "Content-Type: application/json" \
  -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null
