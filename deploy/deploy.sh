#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# deploy.sh <environment> <docs_image> <mcp_image> <image_tag> <mcp_enabled>
# - docker compose stack deployment
# - health check monitoring
# - automated rollback on failure
#
# Uploaded to ~/mcp/<env>/ by CI and invoked remotely via SSH
#
# Applies CI-provided secrets to a local .env file, pulls the specified images
# from GHCR, and deploys the stack. Monitors container health and automatically
# rolls back to the last known-good state if the new deployment fails to start
#
# Secrets arrive as env vars from CI:
# - GHCR_TOKEN, GHCR_ACTOR, DOMAIN, DATABASE_URL, REDIS_PASSWORD
# ==============================================================================

ENVIRONMENT="${1:?environment required (production|development)}"
DOCS_IMAGE_NAME="${2:?docs image name required (ghcr.io/owner/repo-docs)}"
MCP_IMAGE_NAME="${3:?mcp image name required (ghcr.io/owner/repo)}"
IMAGE_TAG="${4:?image tag required (short SHA)}"
MCP_ENABLED="${5:-false}"

: "${GHCR_TOKEN:?GHCR_TOKEN required}"
: "${GHCR_ACTOR:?GHCR_ACTOR required}"
: "${DOMAIN:?DOMAIN required}"

if [[ "$MCP_ENABLED" == "true" ]]; then
  : "${DATABASE_URL:?DATABASE_URL required when mcp is enabled}"
  : "${REDIS_PASSWORD:?REDIS_PASSWORD required when mcp is enabled}"
fi

DIR="$HOME/mcp/$ENVIRONMENT"
cd "$DIR"

PROJECT="mcp-$ENVIRONMENT"
HEALTH_TIMEOUT=90 # seconds

# CUR_ENABLED reflects the stack shape currently being applied (it changes when a
# rollback targets a state whose mcp-enabled flag differs from this run's)
CUR_ENABLED="$MCP_ENABLED"

compose() {
  local pargs=()
  [[ "$CUR_ENABLED" == "true" ]] && pargs=(--profile mcp)
  docker compose -p "$PROJECT" "${pargs[@]}" --env-file .env -f docker-compose.yml "$@"
}

write_env() {
  umask 077
  {
    printf 'ENV=%s\n' "$ENVIRONMENT"
    printf 'DOMAIN=%s\n' "$DOMAIN"
    printf 'DOCS_IMAGE_NAME=%s\n' "$DOCS_IMAGE_NAME"
    printf 'IMAGE_NAME=%s\n' "$MCP_IMAGE_NAME"
    printf 'IMAGE_TAG=%s\n' "$1"
    printf 'DATABASE_URL=%s\n' "${DATABASE_URL:-}"
    printf 'REDIS_PASSWORD=%s\n' "${REDIS_PASSWORD:-}"
  } > .env
  chmod 600 .env
}

deploy_tag() {
  local tag="$1" enabled="$2"
  CUR_ENABLED="$enabled"
  write_env "$tag"
  if [[ "$CUR_ENABLED" != "true" ]]; then
    docker compose -p "$PROJECT" --profile mcp --env-file .env -f docker-compose.yml rm -sf mcp redis >/dev/null 2>&1 || true
  fi
  compose pull
  compose up -d --remove-orphans
}

wait_healthy() {
  local svc cid status
  local -a svcs=(docs)
  [[ "$CUR_ENABLED" == "true" ]] && svcs+=(mcp)
  local deadline=$((SECONDS + HEALTH_TIMEOUT))
  while ((SECONDS < deadline)); do
    local all_ok=true
    for svc in "${svcs[@]}"; do
      cid="$(compose ps -q "$svc" || true)"
      if [[ -z "$cid" ]]; then
        all_ok=false
        continue
      fi
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo starting)"
      [[ "$status" == "unhealthy" ]] && return 1
      [[ "$status" != "healthy" ]] && all_ok=false
    done
    $all_ok && return 0
    sleep 3
  done
  return 1
}

PREV_TAG=""
PREV_ENABLED="false"
if [[ -f .last-good ]]; then
  read -r PREV_TAG PREV_ENABLED < .last-good || true
  PREV_ENABLED="${PREV_ENABLED:-false}"
fi

echo "=== Deploy $ENVIRONMENT: tag $IMAGE_TAG (mcp_enabled=$MCP_ENABLED, previous good: ${PREV_TAG:-none}) ==="
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_ACTOR" --password-stdin

deploy_tag "$IMAGE_TAG" "$MCP_ENABLED"

if wait_healthy; then
  printf '%s %s\n' "$IMAGE_TAG" "$MCP_ENABLED" > .last-good
  echo "=== OK: $ENVIRONMENT healthy on $IMAGE_TAG (mcp_enabled=$MCP_ENABLED) ==="
  exit 0
fi

echo "::error::$ENVIRONMENT unhealthy on $IMAGE_TAG"

if [[ -n "$PREV_TAG" && "$PREV_TAG" != "$IMAGE_TAG" ]]; then
  echo "=== Rolling back to previous good state: $PREV_TAG (mcp_enabled=$PREV_ENABLED) ==="
  deploy_tag "$PREV_TAG" "$PREV_ENABLED"
  if wait_healthy; then
    echo "::warning::Rolled back to $PREV_TAG — service restored, but the deploy of $IMAGE_TAG FAILED."
  else
    echo "::error::Rollback to $PREV_TAG ALSO failed — manual intervention required."
  fi
else
  echo "::error::No previous good version to roll back to (first deploy, or same tag)."
fi

exit 1
