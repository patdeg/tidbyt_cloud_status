# Tidbyt Cloud Status

Displays AWS, GCP, and Azure status on a Tidbyt.

- One row with three columns: logo + status dot per provider
- Icons are embedded (base64) for reliable offline renders
- Refresh and push handled by `refresh.sh` (cron-friendly)

## Requirements

- Pixlet installed and authenticated (`pixlet devices` works)
- Bash, curl, ImageMagick (optional; only needed if regenerating icons)

## Setup

1. Add an `.env` file with your Tidbyt tokens and device IDs:

```
TIDBYT_API_TOKEN_DESK=...
TIDBYT_DEVICE_ID_DESK=...   # or TIDBYT_DEVICE_ID_DECK=...
TIDBYT_API_TOKEN_SHELF=...
TIDBYT_DEVICE_ID_SHELF=...
# Optional
INSTALLATION_ID=cloudstatus
```

2. Test locally:

```
pixlet render tidbyt_cloud_status.star
```

3. Push to devices (renders and pushes):

```
./refresh.sh
```

## Cron

Example every 5 minutes:

```
*/5 * * * * /home/pdeglon/patdeg/tidbyt_cloud_status/refresh.sh >> /home/pdeglon/patdeg/tidbyt_cloud_status/cron.log 2>&1
```

## Assets

- Original logo PNGs are in `assets/`:
  - `assets/aws_logo.png`, `assets/gcp_logo.png`, `assets/azure_logo.png`
- The app embeds optimized base64 versions; updating PNGs does not auto-update the app.
  - If you want me to refresh embedded icons from these PNGs, ask and I’ll regenerate.
