#!/bin/bash

# 1. Find the socket
SOCKET=$(find "/run/user/$UID/hypr/" -maxdepth 2 -name ".hyprsunset.sock" 2>/dev/null | head -n 1)

# 2. Fetch and clean values (keeping only digits)
TEMP=$(echo "temperature" | nc -q 0 -U "$SOCKET" 2>/dev/null | tr -dc '0-9')
GAMMA=$(echo "gamma" | nc -q 0 -U "$SOCKET" 2>/dev/null | tr -dc '0-9')

# 3. Logic for labels and units
if [ -n "$TEMP" ]; then
    # When running: Includes labels and units
    tooltip="TEMP: ${TEMP}K\\nGAMMA: ${GAMMA}%"
else
    # When killed: No labels, no units, just the status
    tooltip="hyprsunset\\nis killed"
fi

# 4. Output JSON for Waybar
printf '{"text": "", "tooltip": "%s"}\n' "$tooltip"
