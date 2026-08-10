#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# maintenance.sh
# - daily server checkup
# - security report to Discord
#
# Run by ops-maintenance.timer (daily)
#
# Report-only by default (non-mutating): security patches are already applied by
# unattended-upgrades. Optionally applies all apt upgrades / prunes docker
#
# CONFIG /etc/ops.env
# ==============================================================================

# Optional external config file (plain KEY=VALUE, not code)
[ -f /etc/ops.env ] && { set -a; . /etc/ops.env; set +a; }

# CONFIG via /etc/ops.env
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
MAINTENANCE_APPLY_ALL_UPGRADES="${MAINTENANCE_APPLY_ALL_UPGRADES:-false}"
MAINTENANCE_DOCKER_PRUNE="${MAINTENANCE_DOCKER_PRUNE:-true}"

readonly LOG_FILE="/var/log/ops-maintenance.log"
export DEBIAN_FRONTEND=noninteractive

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
    local desc="${message:0:3900}"
    local payload
    payload="$(jq -n --arg t "$title" --arg d "$desc" --argjson c "$color" \
        --arg h "$(hostname)" \
        '{embeds:[{title:$t,description:$d,color:$c,footer:{text:$h},timestamp:(now|todate)}]}')"
    curl -fsS --max-time 15 -X POST -H "Content-Type: application/json" \
        -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null || log "Discord send failed."
}

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then echo "Run as root (sudo)."; exit 1; fi

SEVERITY="info"
escalate() {
    case "$1" in
        error)   SEVERITY="error" ;;
        warning) [[ "$SEVERITY" != "error" ]] && SEVERITY="warning" ;;
    esac
}

REPORT=""
add() { REPORT+="$1"$'\n'; log "$1"; }

add "🖥  Host: $(hostname) —$(uptime -p | sed 's/^up/ up/')"
add "🐧 Kernel: $(uname -r)"

# Pending updates
apt-get update -y >/dev/null 2>&1 || escalate warning
if command -v /usr/lib/update-notifier/apt-check >/dev/null 2>&1; then
    IFS=';' read -r ALL SEC < <(/usr/lib/update-notifier/apt-check 2>&1)
else
    ALL="$(apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null | grep -c '^Inst')"
    SEC="$(apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null | grep -c '^Inst.*security')"
fi
add "📦 Updates pending: ${ALL:-?} total, ${SEC:-0} security"
[[ "${SEC:-0}" -gt 0 ]] && escalate warning

# Reboot required
if [[ -f /var/run/reboot-required ]]; then
    add "🔁 REBOOT REQUIRED (auto-reboot happens in the configured window)"
    escalate warning
fi

# Optionally apply all upgrades
if [[ "${MAINTENANCE_APPLY_ALL_UPGRADES,,}" == "true" ]]; then
    if apt-get upgrade -y >/dev/null 2>&1; then
        add "⬆️  Applied all pending apt upgrades."
    else
        add "⚠️  apt upgrade errors — check $LOG_FILE"; escalate error
    fi
    apt-get autoremove -y >/dev/null 2>&1 || true
fi

# Disk / Memory / Load
DISK_PCT="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"
add "💾 Disk /: $(df -h / | awk 'NR==2{print $3" used of "$2" ("$5")"}')"
[[ "${DISK_PCT:-0}" -ge 85 ]] && escalate warning
[[ "${DISK_PCT:-0}" -ge 95 ]] && escalate error
add "🧠 Memory: $(free -h | awk '/^Mem:/{print $3" used of "$2}')"
add "📈 Load:$(uptime | sed 's/.*load average://')"

# Docker health
if command -v docker >/dev/null 2>&1; then
    add "🐳 Docker: $(docker ps -q | wc -l) container(s) running"
    UNHEALTHY="$(docker ps --filter health=unhealthy --format '{{.Names}}' | paste -sd, -)"
    [[ -n "$UNHEALTHY" ]] && { add "🚨 Unhealthy: $UNHEALTHY"; escalate error; }
    EXITED="$(docker ps -a --filter status=exited --filter status=dead --format '{{.Names}}' | paste -sd, -)"
    [[ -n "$EXITED" ]] && { add "⚠️  Exited/dead: $EXITED"; escalate warning; }
    if [[ "${MAINTENANCE_DOCKER_PRUNE,,}" == "true" ]]; then
        # NEVER --volumes
        # Only dangling images, build cache, stopped containers
        RECLAIMED="$( { docker image prune -f; docker builder prune -f; docker container prune -f; } \
            2>/dev/null | grep -i 'reclaimed' | paste -sd'; ' - || true )"
        [[ -n "$RECLAIMED" ]] && add "🧹 Docker cleanup: $RECLAIMED"
    fi
fi

# Security: SSH auth digest (last 24h)
if command -v journalctl >/dev/null 2>&1; then
    FAILED="$(journalctl -u ssh -u sshd --since '24 hours ago' --no-pager 2>/dev/null \
        | grep -c 'Failed password\|Invalid user' || true)"
    ACCEPTED="$(journalctl -u ssh -u sshd --since '24 hours ago' --no-pager 2>/dev/null \
        | grep 'Accepted' | awk '{print $(NF-3)" from "$(NF-1)}' | sort -u | paste -sd'; ' - || true)"
    add "🔐 SSH 24h: ${FAILED:-0} failed attempt(s)"
    [[ -n "$ACCEPTED" ]] && add "✅ SSH logins: $ACCEPTED"
    [[ "${FAILED:-0}" -gt 200 ]] && escalate warning
fi

# Public listeners + ufw
PUBLIC_LISTEN="$(ss -tulnH 2>/dev/null | awk '{print $5}' \
    | grep -E '^(0\.0\.0\.0|\[::\]|\*)' | sort -u | paste -sd', ' - || true)"
add "🌐 Public listeners: ${PUBLIC_LISTEN:-none}"
command -v ufw >/dev/null 2>&1 && add "🧱 ufw: $(ufw status | awk 'NR==1{print $2}')"

# Optional deep audit (Lynis)
if command -v lynis >/dev/null 2>&1; then
    HARDENING="$(lynis audit system --quick --quiet 2>/dev/null \
        | grep -i 'Hardening index' | tail -1 | sed 's/.*: //' || true)"
    [[ -n "$HARDENING" ]] && add "🔎 Lynis hardening index: $HARDENING"
fi

case "$SEVERITY" in
    error)   TITLE="🚨 Daily server report — ACTION NEEDED" ;;
    warning) TITLE="⚠️ Daily server report — warnings" ;;
    *)       TITLE="✅ Daily server report — all good" ;;
esac

notify_discord "$SEVERITY" "$TITLE" "$REPORT"

log "Maintenance run complete (severity: $SEVERITY)."
