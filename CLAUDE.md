# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Two Tidbyt apps in one repo, pushed to the same two devices:

| App | Starlark | Installation id | Shows |
|---|---|---|---|
| Cloud Status | `tidbyt_cloud_status.star` | `cloudstatus` | AWS, GCP, Azure |
| AI Status | `tidbyt_ai_status.star` | `aistatus` | OpenAI, Anthropic, Groq |

Provider icons are embedded as base64 so renders work without network access to
the logo sources; only the *status* lookups hit the network.

## Entry points

```
refresh.sh          # THE cron entry point: refresh_ai.sh, sleep 10, refresh_cloud.sh
refresh_ai.sh       # render + push the AI app to both devices
refresh_cloud.sh    # render + push the cloud app to both devices
```

`refresh.sh` also rotates `/home/pdeglon/logs/tidbyt_cloud_status.log` at 10 MB by
truncating in place, which preserves cron's open fd. That only works while cron
redirects to that exact path -- see README.

The Makefile is a thin convenience wrapper (`make push` just calls `./refresh.sh`);
the shell scripts are the real interface.

## Devices

Both apps push to both devices, using per-device JWTs from `.env`:

| Device | `.env` vars |
|---|---|
| Desk | `TIDBYT_API_TOKEN_DESK` + `TIDBYT_DEVICE_ID_DESK` |
| Shelf | `TIDBYT_API_TOKEN_SHELF` + `TIDBYT_DEVICE_ID_SHELF` |

Both desk variables are spelled `..._DESK`. Until 2026-08-21 the device id was
`TIDBYT_DEVICE_ID_DECK` -- a typo the scripts absorbed with a
`${TIDBYT_DEVICE_ID_DESK:-${TIDBYT_DEVICE_ID_DECK:-}}` fallback. Both the fallback
and the typo are gone; `..._DECK` is no longer read anywhere.

A missing device id is not fatal: the script logs `Skipping DESK: ...` and still
pushes the other device. That line means misconfiguration, not a transient fault.

## Rotating device credentials

Replacing a Tidbyt changes **both** its device id and its API token, and the token
is scoped to the device: a new id paired with an old token returns
`404 device not found` -- indistinguishable from a simply wrong id. Verify the pair
matches before debugging anything else:

```bash
source .env
python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); \
  print(json.loads(base64.urlsafe_b64decode(p))['device'])" "$TIDBYT_API_TOKEN_DESK"
# must print the value of TIDBYT_DEVICE_ID_DESK
```

Quoting is safe here -- every consumer in this repo reads `.env` via bash `source`,
which strips quotes. (The sibling repo `tidbyt_stock_price` has a Makefile that
reads `.env` with GNU make `include`, which does **not** strip quotes; if you copy
patterns between the two repos, that difference matters.)

### `.env` lives on three hosts and drifts

alfred is master and runs the cron. patrick and nasdaq hold dormant copies with no
crons, so nothing there fails loudly when they go stale -- on 2026-08-21 nasdaq was
still pointing at a device that had already been replaced, and patrick had no
`.env` at all. After rotating, sync the replica that has one:

```bash
scp .env nasdaq:~/patdeg/tidbyt_cloud_status/.env
```

Sync code and credentials together, never credentials alone.

## Verify against a real cron cycle, not a manual run

Manual runs can pass while cron fails (different PATH and environment). Isolate the
most recent cycle -- a plain `tail` reaches back into pre-fix lines and will show
stale errors that are already resolved:

```bash
awk '/\[ai-status\].*Starting render/{b=""} {b=b $0 "\n"} END{printf "%s", b}' \
  /home/pdeglon/logs/tidbyt_cloud_status.log
```

Two error classes, only one of which is actionable:

- **Real:** `404`, `device not found`, `Skipping DESK`, `WARNING: Push to ... failed`.
- **Routine:** `context deadline exceeded` fetching a provider status page
  (`status.aws.amazon.com`, `status.claude.com`, ...) followed by
  `render attempt N failed`. These APIs time out regularly; the 3-attempt retry
  absorbs it and the next attempt succeeds. Present in healthy cycles.

The retry loop exists precisely because a single such timeout used to abort the
cycle under `set -e`, leaving the device on its previous frame -- which looked like
a stale-image bug rather than a network blip.

## Environment Configuration

Requires `.env` (gitignored, never committed):

- `TIDBYT_API_TOKEN_DESK` / `TIDBYT_API_TOKEN_SHELF` - device JWTs
- `TIDBYT_DEVICE_ID_DESK` / `TIDBYT_DEVICE_ID_SHELF` - device identifiers
- `INSTALLATION_ID` - optional; defaults to `cloudstatus` / `aistatus` per script.
  Sanitized to alphanumeric, since the Tidbyt API rejects anything else.

## Technology Stack

- **Starlark**: Python-like DSL for Tidbyt apps
- **Pixlet**: CLI for rendering and pushing
