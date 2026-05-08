#!/bin/bash
cd /home/pdeglon/patdeg/tidbyt_cloud_status

# Keep-1 log rotation. Path must match the cron redirect target.
# Truncate-in-place preserves cron's open fd (O_APPEND writes resume at offset 0).
LOG=/home/pdeglon/logs/tidbyt_cloud_status.log
MAX_BYTES=$((10 * 1024 * 1024))
if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG")" -gt "$MAX_BYTES" ]; then
  cp "$LOG" "$LOG.1" && : > "$LOG"
fi

./refresh_ai.sh
sleep 10
./refresh_cloud.sh
