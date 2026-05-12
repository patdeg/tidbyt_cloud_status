#!/bin/bash
# Refresh and push Tidbyt Cloud Status app to two devices.
# Designed for cron usage.

set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/go/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

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

# Render in a clean temp directory to avoid Pixlet applet confusion
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
cp "$STAR" "$TMPDIR/"

# Retry render on transient http.get timeouts inside Starlark. The status
# APIs (status.aws.amazon.com, status.cloud.google.com, etc.) regularly hit
# "context deadline exceeded"; without retries a single timeout aborted the
# cron cycle under `set -e` and the device kept the previous frame, which
# manifested as a "stale image" on the Tidbyt.
render_ok=0
for attempt in 1 2 3; do
  if [ -n "${ARGS:-}" ]; then
    (cd "$TMPDIR" && pixlet render "$STAR" ${ARGS}) && render_ok=1 && break
  else
    (cd "$TMPDIR" && pixlet render "$STAR") && render_ok=1 && break
  fi
  echo "[cloud-status] render attempt $attempt failed"
  [ "$attempt" -lt 3 ] && sleep 5
done

if [ "$render_ok" -ne 1 ]; then
  echo "[cloud-status] render failed after 3 attempts; skipping push"
  exit 0
fi

# Move the rendered image back to project directory
if [ -f "$TMPDIR/$WEBP" ]; then
  mv "$TMPDIR/$WEBP" ./
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
