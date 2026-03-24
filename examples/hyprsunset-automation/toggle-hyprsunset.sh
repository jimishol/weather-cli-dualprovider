#!/bin/sh

# File to track our current toggle state
STATE_FILE="/tmp/hyprsunset_state"

# Check the file to see what the last state was
if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "175" ]; then
    # Was 175, switch to 100
    CMD="--gamma_max 100"
    echo "100" > "$STATE_FILE"
else
    # Was 100 (or nothing was running), switch to 175
    CMD="--gamma_max 175 --gamma 175 --temperature 6500"
    echo "175" > "$STATE_FILE"
fi

# Kill, wait, and apply new settings
/usr/bin/pkill -x hyprsunset >/dev/null 2>&1
sleep 2
setsid /usr/bin/hyprsunset $CMD >/dev/null 2>&1 &
