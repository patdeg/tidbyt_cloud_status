#!/usr/bin/env bash
# Download a logo, resize/optimize for Tidbyt, and output PNG + base64 snippet.
# Usage:
#   scripts/make_logo.sh NAME URL [SIZE]
# Examples:
#   scripts/make_logo.sh aws https://d1.awsstatic.com/logos/aws-logo.png 14
#   scripts/make_logo.sh gcp https://cloud.google.com/_static/cloud/images/social-icon-google-cloud-1200-630.png 14
#   scripts/make_logo.sh azure https://azurecomcdn.azureedge.net/cvt-9c2c5b6b71e9b6f4f4f1f9d1c9d8e1f9d0e2c7a9a1f6f9a1a9b8f6c9d8e1f9/original.png 14

set -euo pipefail

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 2 ]]; then
  echo "Usage: $0 NAME URL [SIZE]" >&2
  exit 1
fi

NAME_RAW="$1"
URL="$2"
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

echo "[make_logo] Downloading $URL"
curl -fsSL "$URL" -o "$RAW_FILE"

# Determine converter: prefer ImageMagick (magick or convert), else rsvg-convert, else inkscape
convert_cmd=""
if command -v magick >/dev/null 2>&1; then
  convert_cmd="magick"
elif command -v convert >/dev/null 2>&1; then
  convert_cmd="convert"
fi

mime="$(file -b --mime-type "$RAW_FILE" || echo application/octet-stream)"

echo "[make_logo] Converting to ${SIZE}x${SIZE} PNG"
if [[ -n "$convert_cmd" ]]; then
  # ImageMagick can handle many formats (PNG/SVG). Keep transparency, center, and limit colors.
  "$convert_cmd" "$RAW_FILE" -background none -alpha on -resize "${SIZE}x${SIZE}" \
    -gravity center -extent "${SIZE}x${SIZE}" -colors 32 -strip "PNG32:$PNG_FILE"
else
  if [[ "$mime" == "image/svg+xml" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$SIZE" -h "$SIZE" "$RAW_FILE" -o "$PNG_FILE"
  elif [[ "$mime" == "image/svg+xml" ]] && command -v inkscape >/dev/null 2>&1; then
    inkscape "$RAW_FILE" --export-type=png --export-width="$SIZE" --export-height="$SIZE" --export-filename="$PNG_FILE" >/dev/null 2>&1
  else
    echo "[make_logo] ERROR: Need ImageMagick (magick/convert) or rsvg-convert/inkscape to process $mime" >&2
    exit 2
  fi
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

