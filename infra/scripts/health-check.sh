#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# health-check.sh
# - post-boot verify
# - self-heal
# - Discord report
#
# Run by ops-boot-health.service (after docker + network)
#
# Waits for Docker, checks the containers you EXPECT are running & healthy,
# attempts one bounded heal, then reports the outcome so every reboot is visible
#
# CONFIG /etc/ops.env
# ==============================================================================

# Optional external config file (plain KEY=VALUE, not code)
[ -f /etc/ops.env ] && { set -a; . /etc/ops.env; set +a; }

# CONFIG via /etc/ops.env
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
EXPECTED_CONTAINERS="${EXPECTED_CONTAINERS:-}"
HEAL_COMMAND="${HEAL_COMMAND:-}"

readonly LOG_FILE="/var/log/ops-health.log"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" | tee -a "$LOG_FILE"; }

# notify_discord <level: success|warning|error|info> <title> <message>
notify_discord() {
    local level="$1" title="$2" message="$3" color
    if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
        log "DISCORD_WEBHOOK_URL not set — skipping notification."; return 0
    fi
    command -v jq >/dev/null 2>&1 || { log "jq missing — cannot notify."; return 1; }
    case "$level" in
        success) color=3066993 ;; warning) color=16776960 ;;
        error)   color=15158332 ;; *)      color=3447003 ;;
    esac
    local payload
    payload="$(jq -n --arg t "$title" --arg d "${message:0:3900}" --argjson c "$color" \
        --arg h "$(hostname)" \
        '{embeds:[{title:$t,description:$d,color:$c,footer:{text:$h},timestamp:(now|todate)}]}')"
    curl -fsS --max-time 15 -X POST -H "Content-Type: application/json" \
        -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null || log "Discord send failed."
}

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then echo "Run as root (sudo)."; exit 1; fi

REPORT=""
add() { REPORT+="$1"$'\n'; log "$1"; }

add "🖥  Host: $(hostname) —$(uptime -p | sed 's/^up/ up/')"

# 1. Wait for the Docker daemon
for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
if ! docker info >/dev/null 2>&1; then
    add "🚨 Docker daemon did NOT come up within ~60s of boot."
    notify_discord error "🚨 Boot health — Docker DOWN" "$REPORT"
    exit 1
fi
add "🐳 Docker up ($(docker ps -q | wc -l) container(s) running)."

# 2. Expected containers
read -ra EXPECTED <<<"$(tr ',' ' ' <<<"$EXPECTED_CONTAINERS")"
if [[ ${#EXPECTED[@]} -eq 0 ]]; then
    add "ℹ️  No EXPECTED_CONTAINERS set — reporting docker state only."
    notify_discord success "✅ Boot health — server back up" "$REPORT"
    exit 0
fi

state()  { docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo missing; }
health() { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null || echo none; }

# 3. Heal if degraded
DEGRADED=()
for c in "${EXPECTED[@]}"; do [[ "$(state "$c")" != "true" ]] && DEGRADED+=("$c"); done
if [[ ${#DEGRADED[@]} -gt 0 ]]; then
    add "⚠️  Not running: ${DEGRADED[*]} — attempting heal..."
    if [[ -n "$HEAL_COMMAND" ]]; then
        bash -c "$HEAL_COMMAND" >>"$LOG_FILE" 2>&1 || add "⚠️  HEAL_COMMAND returned non-zero."
    else
        for c in "${DEGRADED[@]}"; do docker start "$c" >/dev/null 2>&1 || true; done
    fi
    sleep 8
fi

# 4. Final verdict
STILL_DOWN=()
for c in "${EXPECTED[@]}"; do
    s="$(state "$c")"; h="$(health "$c")"
    if   [[ "$s" != "true" ]];    then STILL_DOWN+=("$c"); add "• ❌ $c: not running"
    elif [[ "$h" == "unhealthy" ]]; then STILL_DOWN+=("$c"); add "• 🩺 $c: running but UNHEALTHY"
    else add "• ✅ $c: running ($h)"
    fi
done

if [[ ${#STILL_DOWN[@]} -gt 0 ]]; then
    add "🚨 Still degraded after heal: ${STILL_DOWN[*]}"
    notify_discord error "🚨 Boot health — SERVICES DOWN" "$REPORT"
    exit 1
fi

add "🎉 All ${#EXPECTED[@]} expected service(s) healthy."

notify_discord success "✅ Boot health — all services recovered" "$REPORT"
