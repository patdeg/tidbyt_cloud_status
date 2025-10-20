#!/bin/bash
# Refresh and push Tidbyt Cloud Status app to two devices.
# Designed for cron usage.

set -euo pipefail
export PATH=$PATH:/bin:/usr/bin

# Navigate to this project directory
cd /home/pdeglon/patdeg/tidbyt_cloud_status

# Load environment (tokens + device IDs)
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

APP="tidbyt_cloud_status"
STAR="${APP}.star"
WEBP="${APP}.webp"
# Installation ID must be strictly alphanumeric
INSTALLATION_ID="${INSTALLATION_ID:-cloudstatus}"
SANITIZED_INSTALLATION_ID="$(printf '%s' "$INSTALLATION_ID" | tr -cd '[:alnum:]')"
if [ "$SANITIZED_INSTALLATION_ID" != "$INSTALLATION_ID" ]; then
  echo "[cloud-status] Adjusted installation id to alphanumeric: $SANITIZED_INSTALLATION_ID (from $INSTALLATION_ID)"
fi

# Determine device id var names (support DESK/DECK variants)
DESK_DEVICE_ID="${TIDBYT_DEVICE_ID_DESK:-${TIDBYT_DEVICE_ID_DECK:-}}"
DESK_API_TOKEN="${TIDBYT_API_TOKEN_DESK:-}"
SHELF_DEVICE_ID="${TIDBYT_DEVICE_ID_SHELF:-}"
SHELF_API_TOKEN="${TIDBYT_API_TOKEN_SHELF:-}"

echo "[cloud-status] $(date '+%Y/%m/%d %H:%M:%S') Starting render"
rm -f "$WEBP" || true

# Render the app (pass optional ARGS from env if provided)
if [ -n "${ARGS:-}" ]; then
  pixlet render "$STAR" ${ARGS}
else
  pixlet render "$STAR"
fi

echo "[cloud-status] Render complete: $WEBP"

# Push to DESK device
if [ -n "$DESK_DEVICE_ID" ] && [ -n "$DESK_API_TOKEN" ]; then
  echo "[cloud-status] Pushing to DESK: $DESK_DEVICE_ID"
  if ! pixlet push --installation-id "$SANITIZED_INSTALLATION_ID" --api-token "$DESK_API_TOKEN" "$DESK_DEVICE_ID" "$WEBP"; then
    echo "[cloud-status] WARNING: Push to DESK failed"
  fi
else
  echo "[cloud-status] Skipping DESK: missing TIDBYT_DEVICE_ID_DESK/DECK or TIDBYT_API_TOKEN_DESK"
fi

# Push to SHELF device
if [ -n "$SHELF_DEVICE_ID" ] && [ -n "$SHELF_API_TOKEN" ]; then
  echo "[cloud-status] Pushing to SHELF: $SHELF_DEVICE_ID"
  if ! pixlet push --installation-id "$SANITIZED_INSTALLATION_ID" --api-token "$SHELF_API_TOKEN" "$SHELF_DEVICE_ID" "$WEBP"; then
    echo "[cloud-status] WARNING: Push to SHELF failed"
  fi
else
  echo "[cloud-status] Skipping SHELF: missing TIDBYT_DEVICE_ID_SHELF or TIDBYT_API_TOKEN_SHELF"
fi

echo "[cloud-status] Done"
