#!/usr/bin/env bash

# --- 1. Fetch times ---
WEATHER_SCRIPT="$HOME/.config/waybar/scripts/weather/weather.sh"
SUNRISE=$("$WEATHER_SCRIPT" -p open-meteo -l en | grep -oP '🌅 \K[0-9:]+')
SUNSET=$("$WEATHER_SCRIPT" -p open-meteo -l en | grep -oP '🌇 \K[0-9:]+')

# Fallback values
SUNRISE=${SUNRISE:-06:30}
SUNSET=${SUNSET:-20:00}

# --- 2. Transition Settings ---
TRANSITION_MINS=60  # Total duration of the transition in minutes
STEPS=6             # Number of steps (6 steps of 10 mins = 60 mins)
STEP_MINS=$(( TRANSITION_MINS / STEPS ))

# Define Day and Night target values
DAY_TEMP=6500
DAY_GAMMA=1.00

NIGHT_TEMP=4500
NIGHT_GAMMA=0.80

CONF_FILE="$HOME/.config/hypr/hyprsunset.conf"

# Initialize config
echo "max-gamma = 100" > "$CONF_FILE"
echo "" >> "$CONF_FILE"

# --- 3. Generator Function ---
generate_transition() {
    local start_time=$1
    local start_temp=$2
    local start_gamma=$3
    local end_temp=$4
    local end_gamma=$5

    for (( i=0; i<=STEPS; i++ )); do
        # Calculate the time for this step
        local add_mins=$(( i * STEP_MINS ))
        local cur_time=$(date -d "$start_time today + $add_mins minutes" +%H:%M)
        
        # Linear interpolation using awk
        local cur_temp=$(awk "BEGIN { printf \"%d\", $start_temp + ($i/$STEPS)*($end_temp - $start_temp) }")
        local cur_gamma=$(awk "BEGIN { printf \"%.2f\", $start_gamma + ($i/$STEPS)*($end_gamma - $start_gamma) }")

        echo "profile {" >> "$CONF_FILE"
        echo "    time = $cur_time" >> "$CONF_FILE"
        
        # If it reaches full day targets, use identity
        if [[ "$cur_temp" == "6500" && "$cur_gamma" == "1.00" ]]; then
            echo "    identity = true" >> "$CONF_FILE"
        else
            echo "    temperature = $cur_temp" >> "$CONF_FILE"
            echo "    gamma = $cur_gamma" >> "$CONF_FILE"
        fi
        echo "}" >> "$CONF_FILE"
        echo "" >> "$CONF_FILE"
    done
}

# --- 4. Generate Profiles ---

# Sunrise transition: Night values -> Day values
generate_transition "$SUNRISE" $NIGHT_TEMP $NIGHT_GAMMA $DAY_TEMP $DAY_GAMMA

# Sunset transition: Day values -> Night values
generate_transition "$SUNSET" $DAY_TEMP $DAY_GAMMA $NIGHT_TEMP $NIGHT_GAMMA

# 5. Restart hyprsunset via Hyprland IPC
killall hyprsunset
sleep 1
hyprctl dispatch exec hyprsunset
