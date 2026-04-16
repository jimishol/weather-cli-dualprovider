#!/usr/bin/env bash
# wireplumber_label.sh
# One-shot action handler: perform action and exit when called with args.
# When called with no args, run in continuous event-driven mode for Waybar.

# Configuration: Min alpha (percentage 0-100)
USE_PANGO=true
MIN_ALPHA=35

# --- 1. Action handler for clicks/scrolls ---
if [ -n "${1:-}" ]; then
  action="$1"
  step="${2:-10}"
  if ! [[ "$step" =~ ^[0-9]+$ ]]; then step=10; fi

  case "$action" in
    up)     /usr/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "${step}%+" >/dev/null 2>&1; exit 0 ;;
    down)   /usr/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "${step}%-" >/dev/null 2>&1; exit 0 ;;
    toggle) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1; exit 0 ;;
    mute)   wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1; exit 0 ;;
    unmute) wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1; exit 0 ;;
    # --- 1. Action handler for clicks/scrolls ---
    toggle_sink)
            # 1. Check if the Laptop-specific Virtual/Atmos sink exists
            VIRTUAL_SINK=$(pactl list short sinks | awk '{print $2}' | grep -E "virtual|atmos|easyeffects|convolver" | head -n1)
    
            if [ -n "$VIRTUAL_SINK" ]; then
                # LAPTOP MODE: Toggle between Virtual and Hardware
                CURRENT=$(pactl get-default-sink | tr -d '[:space:]')
                PHYSICAL=$(pactl list short sinks | awk '{print $2}' | grep "alsa_output" | grep -v "hdmi" | head -n1)
    
                if [ "$CURRENT" = "$VIRTUAL_SINK" ] && [ -n "$PHYSICAL" ]; then
                    pactl set-default-sink "$PHYSICAL"
                else
                    pactl set-default-sink "$VIRTUAL_SINK"
                fi
            else
                # DESKTOP/NO-VIRTUAL MODE: Print error to console only
                echo "No virtual sink found matching: virtual|atmos|easyeffects|convolver" >&2
            fi
            exit 0 ;;
    *) ;; # unknown action -> fall through
  esac
fi

# --- 2. JSON output function ---
output_json() {
  local device_type="$1"
  local volume="$2"
  local muted="$3"
  local node_name="$4"

  # 1. Clean up volume input
  if ! [[ "$volume" =~ ^[0-9]+$ ]]; then
    volume=${volume%%.*}
    volume=${volume:-0}
  fi

  # 2. Pick the base icon (The "Steady" icons)
  case "$device_type" in
    v_headphones|*v_headphones*) icon="V"; device_label="Virtual Headphones" ;;
    v_speakers|*v_speakers*)      icon="V"; device_label="Virtual Speakers" ;;
    *headphones*)                 icon=""; device_label="Headphones" ;;
    *speakers*)                   icon=""; device_label="Speakers" ;;
    *)                            icon=""; device_label="Device" ;;
  esac

  # 3. Handle Muted vs. Unmuted states
  if [ "$muted" = "yes" ]; then
    final_text=""
    tooltip_text="$device_label Muted"
    percentage_val=0
    class_val="muted"
  else
    # --- This is where USE_PANGO is involved ---
    if [ "$USE_PANGO" = true ]; then
      # Calculate alpha: Start at MIN_ALPHA, scale up to 100 based on volume
      local alpha=$(( MIN_ALPHA + (volume * (100 - MIN_ALPHA) / 100) ))
      # Wrap icon in the "Glow" markup
      final_text="<span alpha='${alpha}%'>$icon</span>"
    else
      # Standard "Steady" icon without fading
      final_text="$icon"
    fi
    
    tooltip_text="$device_label ${volume}%"
    percentage_val="$volume"
    class_val="$device_type"
  fi

  # 4. Output the final JSON for Waybar
  jq -nc --arg text "$final_text" \
         --arg tooltip "$tooltip_text" \
         --arg class "$class_val" \
         --arg device "$device_label" \
         --argjson percentage "$percentage_val" \
         '{text: $text, tooltip: $tooltip, class: $class, device: $device, percentage: $percentage}'
}

# --- 3. Setup global temporary file once ---
TMP_FILE=$(mktemp /tmp/pactl_sinks.XXXXXX)
trap 'rm -f "$TMP_FILE"' EXIT

# --- 4. Helper functions ---
get_block_by_name() {
    awk -v name="$1" 'BEGIN{RS="\n\n";FS="\n"} {
        for(i=1;i<=NF;i++){ line=$i; sub(/^[ \t]+/,"",line); if(line ~ /^Name:[ \t]*/){
            ln=line; sub(/^Name:[ \t]*/,"",ln); if(ln==name){ print; exit }
        }}
    }' "$TMP_FILE"
}
get_block_by_objectid() {
    awk -v id="$1" 'BEGIN{RS="\n\n";FS="\n"} $0 ~ ("object.id[[:space:]]*=[[:space:]]*\"" id "\"") {print; exit}' "$TMP_FILE"
}
get_active_port_from_block() { awk -F': ' '/Active Port:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$1"; }
is_block_virtual() { 
    # Check the technical Name/Profile, which stays English regardless of System Language
    if grep -qiE "virtual|atmos|surround" <<<"$1"; then 
        echo "yes"
    fi
}

# --- 5. Main Status Gathering Logic (wrapped in a function) ---
print_status() {
    volume=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '{print $5}' | sed 's/%//')
    muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    node_name=$(pactl info 2>/dev/null | awk -F': ' '/Default Sink/ {print $2}')

    if [ -z "$node_name" ]; then
        output_json "default" "0" "no" "Unknown"
        return
    fi

    # Update our temporary file with fresh data
    pactl list sinks 2>/dev/null > "$TMP_FILE" || { output_json "default" "${volume:-0}" "${muted:-no}" "$node_name"; return; }

    def_block=$(get_block_by_name "$node_name")
    if [ -z "$def_block" ]; then
        output_json "default" "${volume:-0}" "${muted:-no}" "$node_name"
        return
    fi

# --- 1. MODE DETECTION (Language Independent) ---
    is_v="no"
    # Check the technical Name string for 'surround' or 'virtual'
    if grep -qiE "virtual|atmos|surround" <<<"$def_block"; then
        is_v="yes"
    fi

    # --- 2. PORT IDENTIFICATION ---
    port=$(get_active_port_from_block "$def_block")

    # If it's a virtual sink with no direct port, look at the parent hardware
    if [ "$is_v" = "yes" ] && [ -z "$port" ]; then
        driver_id=$(awk -F'=' '/node.driver-id/ {gsub(/"/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$def_block")
        if [ -n "$driver_id" ]; then
             under_block=$(get_block_by_objectid "$driver_id")
             port=$(get_active_port_from_block "$under_block")
        fi
    fi

    # --- 3. ICON CATEGORIZATION ---
    case "$port" in
        *headphones*|*headset*)
            base_type="headphones" 
            ;;
        *mic*)
            # Guard: If port is just a mic, keep speaker icon
            base_type="speakers" 
            ;;
        *speaker*|*hdmi*|*surround*|*lineout*|*analog-output*)
            base_type="speakers" 
            ;;
        *)
            # Final fallback scan for any active physical headphones
            phys_has_hp=$(awk 'BEGIN{RS="\n\n";FS="\n";IGNORECASE=1} {name=""; for(i=1;i<=NF;i++) if($i ~ /^Name: /){sub(/^Name: /,"",$i); name=$i} if(name!="" && tolower(name) !~ /virtual|surround|atmos/){ for(i=1;i<=NF;i++) if($i ~ /Active Port:/ && tolower($i) ~ /headphones/ && tolower($i) !~ /mic/){print "yes"; exit}} }' "$TMP_FILE")
            [ "$phys_has_hp" = "yes" ] && base_type="headphones" || base_type="speakers"
            ;;
    esac

    # --- 4. FINAL TYPE ASSIGNMENT ---
    if [ "$is_v" = "yes" ]; then
        device_type="v_$base_type"
    else
        device_type="$base_type"
    fi

    output_json "$device_type" "${volume:-0}" "${muted:-no}" "$node_name"
}

# --- 6. Execution ---
# Print the status once immediately on startup
print_status

# Enter infinite loop waiting for audio events
pactl subscribe 2>/dev/null | grep --line-buffered -E "sink|server" | while read -r event; do
    print_status
done
