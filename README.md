# Tidbyt Cloud Status

Displays AWS, GCP, and Azure status on a Tidbyt.

- One row with three columns: logo + status dot per provider
- Icons are embedded (base64) for reliable offline renders
- Refresh and push handled by `refresh.sh` (cron-friendly)

Also includes a companion AI Status app for OpenAI, Anthropic, and Groq using their favicons (embedded as base64) and Status pages for health.

## Requirements

- Pixlet installed. Interactive auth is **not** required: `refresh_cloud.sh` and
  `refresh_ai.sh` authenticate per device with `--api-token` from `.env`.
  (`pixlet devices` needs interactive auth, but nothing in the cron path uses it.)
- Bash, curl, ImageMagick (optional; only needed if regenerating icons)

## Setup

1. Add an `.env` file with your Tidbyt tokens and device IDs:

```
TIDBYT_API_TOKEN_DESK=...
TIDBYT_DEVICE_ID_DESK=...
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

`refresh.sh` is the single entry point: it runs the AI app, sleeps 10s, then the
cloud app. The installed crontab on alfred is:

```
*/5 * * * * /home/pdeglon/patdeg/tidbyt_cloud_status/refresh.sh >> /home/pdeglon/logs/tidbyt_cloud_status.log 2>&1
```

The log path matters: `refresh.sh` rotates `/home/pdeglon/logs/tidbyt_cloud_status.log`
by truncating in place at 10 MB, which only works if cron redirects to that exact
file. Do not point the redirect elsewhere without updating `LOG` in `refresh.sh`.

## Assets

- Original logo PNGs are in `assets/`:
  - `assets/aws_logo.png`, `assets/gcp_logo.png`, `assets/azure_logo.png`
- The app embeds optimized base64 versions; updating PNGs does not auto-update the app.
  - If you want me to refresh embedded icons from these PNGs, ask and I’ll regenerate.

## AI Status (OpenAI, Anthropic, Groq)

- Render locally:

```
pixlet render tidbyt_ai_status.star
```

- Push to devices:

```
./refresh_ai.sh
```

- No separate cron needed: `refresh.sh` already runs this app before the cloud one.
  Add one only if you want the two apps on different schedules.

### Icon generator updates

The `scripts/make_logo.sh` helper now auto-picks sources for known names when URL is omitted:

- `aws` → https://a0.awsstatic.com/libra-css/images/site/touch-icon-iphone-114-smile.png
- `gcp` → https://cloud.google.com/favicon.ico
- `azure` → https://azure.microsoft.com/favicon.ico
- `openai` → https://chatgpt.com/favicon.ico
- `anthropic` → https://www.anthropic.com/favicon.ico
- `groq` → https://groq.com/favicon.ico

Usage examples:

```
scripts/make_logo.sh aws         # default source, 14x14
scripts/make_logo.sh openai 16   # default source, 16x16
scripts/make_logo.sh groq https://example.com/icon.png 14
```
