#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runs ON THE SERVER (uploaded to ~/mcp/<env>/ by CI, then invoked over SSH)
#
# Health-gated deploy with image-level auto-rollback:
#   1. record the previous good tag (~/mcp/<env>/.last-good)
#   2. pull + up the new image, poll its healthcheck
#   3. healthy  -> record it as the new good tag
#      unhealthy -> roll back to the previous good image, then FAIL the job
#
# Secrets arrive as env vars from CI:
# GHCR_TOKEN, GHCR_ACTOR, DATABASE_URL, REDIS_PASSWORD, DOMAIN.
#
# Usage: deploy.sh <environment> <image_name> <image_tag>
# ==============================================================================

ENVIRONMENT="${1:?environment required (production|development)}"
IMAGE_NAME="${2:?image name required (ghcr.io/owner/repo)}"
IMAGE_TAG="${3:?image tag required (short SHA)}"

: "${GHCR_TOKEN:?GHCR_TOKEN required}"
: "${GHCR_ACTOR:?GHCR_ACTOR required}"
: "${DATABASE_URL:?DATABASE_URL required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD required}"
: "${DOMAIN:?DOMAIN required}"

DIR="$HOME/mcp/$ENVIRONMENT"
cd "$DIR"

PROJECT="mcp-$ENVIRONMENT"
HEALTH_TIMEOUT=90 # seconds

compose() {
  docker compose -p "$PROJECT" --env-file .env -f docker-compose.yml "$@"
}

write_env() {
  umask 077
  {
    printf 'ENV=%s\n' "$ENVIRONMENT"
    printf 'IMAGE_NAME=%s\n' "$IMAGE_NAME"
    printf 'IMAGE_TAG=%s\n' "$1"
    printf 'DOMAIN=%s\n' "$DOMAIN"
    printf 'DATABASE_URL=%s\n' "$DATABASE_URL"
    printf 'REDIS_PASSWORD=%s\n' "$REDIS_PASSWORD"
  } > .env
  chmod 600 .env
}

deploy_tag() {
  local tag="$1"
  write_env "$tag"
  compose pull
  compose up -d --remove-orphans
}

wait_healthy() {
  local cid status deadline=$((SECONDS + HEALTH_TIMEOUT))
  while ((SECONDS < deadline)); do
    cid="$(compose ps -q mcp || true)"
    if [[ -n "$cid" ]]; then
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo starting)"
      [[ "$status" == "healthy" ]] && return 0
      [[ "$status" == "unhealthy" ]] && return 1
    fi
    sleep 3
  done
  return 1
}

PREV="$(cat .last-good 2>/dev/null || true)"

echo "=== Deploy $ENVIRONMENT: $IMAGE_NAME:$IMAGE_TAG (previous good: ${PREV:-none}) ==="
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_ACTOR" --password-stdin

deploy_tag "$IMAGE_TAG"

if wait_healthy; then
  echo "$IMAGE_TAG" > .last-good
  echo "=== OK: $ENVIRONMENT healthy on $IMAGE_TAG ==="
  exit 0
fi

echo "::error::$ENVIRONMENT unhealthy on $IMAGE_TAG"

if [[ -n "$PREV" && "$PREV" != "$IMAGE_TAG" ]]; then
  echo "=== Rolling back to previous good image: $PREV ==="
  deploy_tag "$PREV"
  if wait_healthy; then
    echo "::warning::Rolled back to $PREV — service restored, but the deploy of $IMAGE_TAG FAILED."
  else
    echo "::error::Rollback to $PREV ALSO failed — manual intervention required."
  fi
else
  echo "::error::No previous good version to roll back to (first deploy, or same tag)."
fi

exit 1
