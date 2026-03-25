#!/bin/sh

STATE_FILE="/tmp/hyprsunset_state"
CONF_FILE="$HOME/.config/hypr/hyprsunset.conf"

# -----------------------------------------
# Read low gamma from config
# -----------------------------------------
LOW_GAMMA="$(grep -E '^\s*max-gamma\s*=' "$CONF_FILE" 2>/dev/null \
    | awk -F '=' '{print $2}' \
    | tr -d '[:space:]')"

LOW_GAMMA="${LOW_GAMMA:-100}"

# -----------------------------------------
# Determine boost value
# -----------------------------------------
BOOST_BRIGHT="${BOOST_BRIGHT:-145}"

# If user passed a numeric argument, override boost
case "$1" in
    '' ) ;;  # no argument, normal toggle
    ON_OFF ) FORCE_ON_OFF=1 ;;
    NORMAL ) FORCE_NORMAL=1 ;;
    * )
        # numeric?
        if printf "%s" "$1" | grep -Eq '^[0-9]+$'; then
            BOOST_BRIGHT="$1"
        fi
    ;;
esac

# -----------------------------------------
# Helper: kill hyprsunset and wait until dead
# -----------------------------------------
kill_hyprsunset() {
    /usr/bin/pkill -x hyprsunset >/dev/null 2>&1

    # Wait up to ~1 second without sleep
    i=0
    while pgrep -x hyprsunset >/dev/null 2>&1; do
        i=$((i+1))
        [ "$i" -gt 50 ] && break   # safety break
        usleep 20000               # 20ms
    done
}

# -----------------------------------------
# Read last state
# -----------------------------------------
LAST_STATE="$(cat "$STATE_FILE" 2>/dev/null)"

# -----------------------------------------
# Forced ON_OFF (toggle between kill and normal launch)
# -----------------------------------------
if [ "$FORCE_ON_OFF" = "1" ]; then
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        # running -> kill
        kill_hyprsunset
    else
        # not running -> launch normal
        setsid /usr/bin/hyprsunset --gamma_max "$LOW_GAMMA" >/dev/null 2>&1 &
    fi
    echo "NORMAL" > "$STATE_FILE"
    exit 0
fi

# -----------------------------------------
# Forced NORMAL
# -----------------------------------------
if [ "$FORCE_NORMAL" = "1" ]; then
    kill_hyprsunset
    setsid /usr/bin/hyprsunset --gamma_max "$LOW_GAMMA" >/dev/null 2>&1 &
    echo "NORMAL" > "$STATE_FILE"
    exit 0
fi

# -----------------------------------------
# Automatic toggle logic
# -----------------------------------------
case "$LAST_STATE" in
    ON_OFF )
        # ON_OFF (legacy/alternate) → BOOST
        kill_hyprsunset
        setsid /usr/bin/hyprsunset --gamma_max "$BOOST_BRIGHT" --gamma "$BOOST_BRIGHT" --temperature 6500 >/dev/null 2>&1 &
        echo "BOOST" > "$STATE_FILE"
    ;;
    BOOST )
        # BOOST → NORMAL
        kill_hyprsunset
        setsid /usr/bin/hyprsunset --gamma_max "$LOW_GAMMA" >/dev/null 2>&1 &
        echo "NORMAL" > "$STATE_FILE"
    ;;
    NORMAL | * )
        # NORMAL or unknown → BOOST
        kill_hyprsunset
        setsid /usr/bin/hyprsunset --gamma_max "$BOOST_BRIGHT" --gamma "$BOOST_BRIGHT" --temperature 6500 >/dev/null 2>&1 &
        echo "BOOST" > "$STATE_FILE"
    ;;
esac
