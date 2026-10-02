#!/usr/bin/env bash
# Convert JPG/PNG images to WebP, scaled down to a maximum width.
# The .webp file is written next to the original (same name, new extension).
#
# Usage: scripts/to-webp.sh [-w width] [-q quality] [-f] <file|dir>...
#   -w  max width in px (default 1280); smaller images are never upscaled
#   -q  WebP quality 0-100 (default 82)
#   -f  overwrite existing .webp files
#
# Examples:
#   scripts/to-webp.sh static/img/works/28x/cover.png
#   scripts/to-webp.sh -q 85 static/img/works

set -euo pipefail

width=1280
quality=82
force=0

while getopts "w:q:fh" opt; do
    case $opt in
        w) width=$OPTARG ;;
        q) quality=$OPTARG ;;
        f) force=1 ;;
        *) sed -n '2,13p' "$0"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
    sed -n '2,13p' "$0"
    exit 1
fi

command -v cwebp >/dev/null || { echo "cwebp not found (install the 'webp' package)"; exit 1; }

# Image width from `file` output. The last "WxH" match is the real size
# (JPEG output can contain an earlier "density 72x72").
image_width() {
    file -b "$1" | grep -oE '[0-9]+ ?x ?[0-9]+' | tail -n1 | grep -oE '^[0-9]+'
}

convert() {
    local src=$1
    local dst="${src%.*}.webp"

    if [ -e "$dst" ] && [ $force -eq 0 ]; then
        echo "skip   $dst (exists, use -f to overwrite)"
        return
    fi

    local resize=()
    local w
    w=$(image_width "$src" || true)
    if [ -n "$w" ] && [ "$w" -gt "$width" ]; then
        resize=(-resize "$width" 0)
    fi

    cwebp -quiet -q "$quality" -m 6 -sharp_yuv -metadata icc "${resize[@]}" "$src" -o "$dst"

    local before after
    before=$(du -k "$src" | cut -f1)
    after=$(du -k "$dst" | cut -f1)
    printf '%-6s %s  %s KB -> %s KB%s\n' "ok" "$dst" "$before" "$after" \
        "$([ ${#resize[@]} -gt 0 ] && echo "  (${w}px -> ${width}px)")"
}

for arg in "$@"; do
    if [ -d "$arg" ]; then
        while IFS= read -r -d '' f; do
            convert "$f"
        done < <(find "$arg" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)
    elif [ -f "$arg" ]; then
        convert "$arg"
    else
        echo "not found: $arg"
    fi
done
