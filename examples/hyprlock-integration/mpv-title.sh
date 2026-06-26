#!/usr/bin/env bash

# -----------------------------
# CONFIG: toggle metadata ON/OFF
# -----------------------------
SHOW_METADATA=true
# SHOW_METADATA=false
# -----------------------------

SOCK="/tmp/mpv-socket"

# If metadata is disabled → print nothing
if [[ "$SHOW_METADATA" == "false" ]]; then
    echo ""
    exit 0
fi

[[ -S "$SOCK" ]] || { echo ""; exit 0; }

# Query metadata (ICY + basic tags)
meta=$(printf '%s\n' '{ "command": ["get_property", "metadata"] }' \
       | nc -U -q 0 "$SOCK" 2>/dev/null)

# Query media-title
title=$(printf '%s\n' '{ "command": ["get_property", "media-title"] }' \
        | nc -U -q 0 "$SOCK" 2>/dev/null \
        | jq -r '.data // empty')

# Query Composer explicitly (works for OGG/FLAC/Opus)
composer_tag=$(printf '%s\n' '{ "command": ["get_property", "metadata/by-key/Composer"] }' \
               | nc -U -q 0 "$SOCK" 2>/dev/null \
               | jq -r '.data // empty')

# Extract ICY title
icy=$(echo "$meta" | jq -r '.data["icy-title"] // empty')

# Prefer ICY title if present
if [[ -n "$icy" ]]; then
    main="$icy"
else
    main="$title"
fi

# Composer from tag if available
composer="$composer_tag"

# If no Composer tag, try to extract from icy-title
if [[ -z "$composer" && -n "$icy" ]]; then
    composer=$(echo "$icy" | grep -oE ' - [A-Za-zΑ-Ωα-ω .]+ -' | sed 's/ - //g' | sed 's/ -$//')
fi

# Clean composer
composer=$(echo "$composer" | sed 's/--*/-/g' | sed 's/-$//' | sed 's/^ *//;s/ *$//')

# Word-wrap
wrapped_main=$(echo "$main" | fold -s -w 60)
wrapped_composer=$(echo "$composer" | fold -s -w 60)

# Print title
printf "%s\n" "$wrapped_main"

# Print composer only if valid
if [[ -n "$composer" ]]; then
    printf "%s\n" "$wrapped_composer"
fi
