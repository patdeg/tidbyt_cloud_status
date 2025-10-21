#!/usr/bin/env bash
# Download a logo, resize/optimize for Tidbyt, and output PNG + base64 snippet.
# Usage:
#   scripts/make_logo.sh NAME [URL] [SIZE]
# Notes:
#   - If URL is omitted, a default source is used for known names.
#   - SIZE defaults to 14.
# Examples (new sources):
#   scripts/make_logo.sh aws                            # uses https://a0.awsstatic.com/libra-css/images/site/touch-icon-iphone-114-smile.png
#   scripts/make_logo.sh gcp                            # uses https://cloud.google.com/favicon.ico
#   scripts/make_logo.sh azure                          # uses https://azure.microsoft.com/favicon.ico
#   scripts/make_logo.sh openai                         # uses https://chatgpt.com/favicon.ico
#   scripts/make_logo.sh anthropic                      # uses https://www.anthropic.com/favicon.ico
#   scripts/make_logo.sh groq                           # uses https://groq.com/favicon.ico
#   scripts/make_logo.sh aws https://example.com/logo.png 16

set -euo pipefail

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  echo "Usage: $0 NAME [URL] [SIZE]" >&2
  exit 1
fi

NAME_RAW="$1"
URL_INPUT="${2:-}"
SIZE="${3:-14}"

NAME="$(echo "$NAME_RAW" | tr '[:lower:]-' '[:upper:]_' | sed -E 's/[^A-Z0-9_]+/_/g')"
VAR_NAME="${NAME}_ICON"

ROOT_DIR="$(cd -- "$(dirname -- "$0")"/.. && pwd)"
ASSETS_DIR="$ROOT_DIR/assets"
SNIPPETS_DIR="$ROOT_DIR/snippets"
mkdir -p "$ASSETS_DIR" "$SNIPPETS_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

RAW_FILE="$TMP_DIR/raw"
PNG_FILE="$ASSETS_DIR/${NAME_RAW}.png"
B64_FILE="$ASSETS_DIR/${NAME_RAW}.b64"
SNIPPET_FILE="$SNIPPETS_DIR/${NAME_RAW}_icon.star.snippet"

# Map known names to default URLs if not provided
lower_name="$(echo "$NAME_RAW" | tr '[:upper:]' '[:lower:]')"
default_url=""
case "$lower_name" in
  aws)
    default_url="https://a0.awsstatic.com/libra-css/images/site/touch-icon-iphone-114-smile.png"
    ;;
  gcp|google|googlecloud)
    default_url="https://cloud.google.com/favicon.ico"
    ;;
  azure|microsoft-azure)
    default_url="https://azure.microsoft.com/favicon.ico"
    ;;
  openai|chatgpt)
    default_url="https://chatgpt.com/favicon.ico"
    ;;
  anthropic|claude)
    default_url="https://www.anthropic.com/favicon.ico"
    ;;
  groq)
    default_url="https://groq.com/favicon.ico"
    ;;
esac

URL="${URL_INPUT:-$default_url}"
if [[ -z "$URL" ]]; then
  echo "[make_logo] ERROR: No URL provided and no default for name '$NAME_RAW'" >&2
  exit 1
fi

echo "[make_logo] Downloading $URL"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Safari/537.36"
if ! curl -fsSL -A "$UA" "$URL" -o "$RAW_FILE"; then
  # Optional fallback for certain names (e.g., favicon blocked)
  if [[ "$lower_name" == "openai" || "$lower_name" == "chatgpt" ]]; then
    FALLBACK_URL="https://icons.duckduckgo.com/ip3/chatgpt.com.ico"
    echo "[make_logo] Primary download failed; trying fallback: $FALLBACK_URL"
    if ! curl -fsSL -A "$UA" "$FALLBACK_URL" -o "$RAW_FILE"; then
      echo "[make_logo] ERROR: download failed for $URL and fallback $FALLBACK_URL" >&2
      exit 2
    fi
  else
    echo "[make_logo] ERROR: download failed for $URL" >&2
    exit 2
  fi
fi

# Determine converter: prefer ImageMagick (magick or convert), else rsvg-convert, else inkscape
convert_cmd=""
if command -v magick >/dev/null 2>&1; then
  convert_cmd="magick"
elif command -v convert >/dev/null 2>&1; then
  convert_cmd="convert"
fi

mime="$(file -b --mime-type "$RAW_FILE" || echo application/octet-stream)"
echo "[make_logo] Detected MIME: $mime"

echo "[make_logo] Converting to ${SIZE}x${SIZE} PNG"
converted=false
if [[ -n "$convert_cmd" && "$mime" != "image/vnd.microsoft.icon" ]]; then
  if "$convert_cmd" "$RAW_FILE" -background none -alpha on -resize "${SIZE}x${SIZE}" \
    -gravity center -extent "${SIZE}x${SIZE}" -colors 32 -strip "PNG32:$PNG_FILE"; then
    converted=true
  fi
fi

if [[ "$converted" = false ]]; then
  if [[ "$mime" == "image/svg+xml" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$SIZE" -h "$SIZE" "$RAW_FILE" -o "$PNG_FILE"
    converted=true
  elif [[ "$mime" == "image/svg+xml" ]] && command -v inkscape >/dev/null 2>&1; then
    inkscape "$RAW_FILE" --export-type=png --export-width="$SIZE" --export-height="$SIZE" --export-filename="$PNG_FILE" >/dev/null 2>&1
    converted=true
  fi
fi

# Fallback: use Python Pillow to handle ICO/PNG and resize/pad
if [[ "$converted" = false ]]; then
  python3 - "$RAW_FILE" "$PNG_FILE" "$SIZE" <<'PY'
import sys
from PIL import Image

src_path, dst_path, size_s = sys.argv[1:4]
size = int(size_s)

img = Image.open(src_path)
img = img.convert("RGBA")
img.thumbnail((size, size), Image.LANCZOS)

canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
ox = (size - img.width) // 2
oy = (size - img.height) // 2
canvas.paste(img, (ox, oy), img)
canvas.save(dst_path, format="PNG")
print("[make_logo] Pillow converted and resized ->", dst_path)
PY
fi

echo "[make_logo] Writing base64 to $B64_FILE"
if base64 --help 2>&1 | grep -q -- "-w"; then
  base64 -w0 "$PNG_FILE" > "$B64_FILE"
else
  base64 "$PNG_FILE" | tr -d '\n' > "$B64_FILE"
fi

echo "[make_logo] Emitting Starlark snippet at $SNIPPETS_DIR"
cat > "$SNIPPET_FILE" <<EOF
# Snippet for ${VAR_NAME}
load("encoding/base64.star", "base64")

${VAR_NAME} = base64.decode("""
$(cat "$B64_FILE")
""")
EOF

echo "[make_logo] Done:"
echo "  PNG:      $PNG_FILE"
echo "  Base64:   $B64_FILE"
echo "  Snippet:  $SNIPPET_FILE"
echo
echo "Paste the snippet into your .star and use: render.Image(src=${VAR_NAME}, width=${SIZE}, height=${SIZE})"
