#!/usr/bin/env bash
# wireplumber_label.sh
# One-shot action handler: perform action and exit when called with args.
# When called with no args, run in continuous event-driven mode for Waybar.

# NOTE: For deterministic virtual-sink detection, name PipeWire filter sinks like:
#   node.name = "effect_input.<NAME>"
# The script prefers that pattern but will fall back to driver-id mapping
# (node.driver-id -> object.id/object.serial) and then to the first non-effect_input sink.

# CONFIGURATION - START

# Min alpha (percentage 0-100)
USE_PANGO="true"
MIN_ALPHA=30
# Output Colors
SPEAKERS_COLOR="#e6e6e6"      # Soft Light Gray (clean, neutral stereo output)
VSPEAKERS_COLOR="#ff5a5a"     # Brightened Red (clear alert/error)
HEADPHONES_COLOR="#00e5e5"    # Darker Aqua (smooth, cool stereo)
VHEADPHONES_COLOR="#e6b800"   # Deep Gold (warm, premium virtual processing)

# Set to "true" to enable dunst progress bars, "false" to disable.
DUNST_NOTIFY_VOLUME="false"

# --- SINK MENU CONFIGURATION ---
# Set to "true" to use a menu (wofi/rofi) for sink selection. Set to "false" to cycle.
MENU="false"
# Command to launch the menu. 
# Menu command to use. Examples: "wofi --dmenu" or "rofi -dmenu" or "fuzzel -dmenu"
MENU_COMMAND="wofi --dmenu --width 500 --height 400"

# CONFIGURATION - END

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
      if [ "$MENU" = "true" ]; then
        # 1. Gather sinks into a hidden map: RAW_NAME <tab> CLEAN_DISPLAY_NAME
        SINK_DATA=$(LC_ALL=C pactl list sinks 2>/dev/null | awk '
          /^[ \t]*Name:/ { 
            name=$2
          }
          /^[ \t]*Description:/ { 
            desc=$0
            # Clean up the "Description: " prefix
            sub(/^[ \t]*Description:[ \t]*/, "", desc)
            
            # Mimic Tooltip Logic: If it is a virtual sink
            if (name ~ /effect_input\./) {
              display = name
              # Extract everything after the last dot
              sub(/.*\./, "", display)
            } else {
              # For physical sinks, use the friendly hardware name
              display = desc
            }
            
            # Output with a hidden tab separator
            print name "\t" display
          }
        ')

        if [ -z "$SINK_DATA" ]; then
          echo "No sinks found." >&2
          exit 0
        fi

        # 2. Extract ONLY the clean display names (column 2) to feed to Wofi
        MENU_ITEMS=$(awk -F'\t' '{print $2}' <<< "$SINK_DATA")

        # 3. Show the menu using your MENU_COMMAND variable
        # Wofi will now ONLY show clean names like "JamesDSP" or "Εσωτερικός ήχος"
        SELECTED=$(echo "$MENU_ITEMS" | sed '/^$/d' | $MENU_COMMAND --prompt "Select Audio Sink")

        # 4. If the user picked something, match it back to the hidden raw name and apply it
        if [ -n "$SELECTED" ]; then
          while IFS=$'\t' read -r raw display; do
            if [ "$SELECTED" = "$display" ]; then
              pactl set-default-sink "$raw"
              break
            fi
          done <<< "$SINK_DATA"
        fi
        exit 0
      fi

      # --- EXISTING CYCLE LOGIC (Runs if MENU="false") ---
      mapfile -t VIRTUAL_SINKS < <(pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -E "effect_input\." || true)
      mapfile -t PHYSICAL_SINKS < <(pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -v -E "effect_input\." || true)

      if [ "${#VIRTUAL_SINKS[@]}" -eq 0 ] && [ "${#PHYSICAL_SINKS[@]}" -eq 0 ]; then
        echo "No sinks found." >&2
        exit 0
      fi

      cycle=()
      for v in "${VIRTUAL_SINKS[@]}"; do cycle+=("$v"); done
      for p in "${PHYSICAL_SINKS[@]}"; do cycle+=("$p"); done

      CURRENT=$(pactl get-default-sink 2>/dev/null | tr -d '[:space:]')
      if [ -z "$CURRENT" ]; then
        NEXT="${cycle[0]}"
        pactl set-default-sink "$NEXT"
        exit 0
      fi

      idx=-1
      for i in "${!cycle[@]}"; do
        if [ "${cycle[$i]}" = "$CURRENT" ]; then
          idx=$i
          break
        fi
      done

      if [ "$idx" -ge 0 ]; then
        next_idx=$(( (idx + 1) % ${#cycle[@]} ))
        NEXT="${cycle[$next_idx]}"
        pactl set-default-sink "$NEXT"
      else
        if [ "${#VIRTUAL_SINKS[@]}" -gt 0 ]; then
          pactl set-default-sink "${VIRTUAL_SINKS[0]}"
        else
          pactl set-default-sink "${PHYSICAL_SINKS[0]}"
        fi
      fi
      exit 0 ;;
    *) ;; # unknown action -> fall through
  esac
fi

output_json() {
  local device_type="$1"
  local volume="$2"       # the sink's own volume (for tooltip)
  local muted="$3"
  local node_name="$4"
  local heard_volume="${5:-}"  # optional: effective heard volume (0-100)

  # 1. Clean up volume input (tooltip volume)
  if ! [[ "$volume" =~ ^[0-9]+$ ]]; then
    volume=${volume%%.*}
    volume=${volume:-0}
  fi

  # If heard_volume provided, sanitize it too (used for alpha)
  if [ -n "$heard_volume" ]; then
    if ! [[ "$heard_volume" =~ ^[0-9]+$ ]]; then
      heard_volume=${heard_volume%%.*}
      heard_volume=${heard_volume:-0}
    fi
  fi

  # 2. Pick the base icon and color
  case "$device_type" in
    v_headphones|*v_headphones*) 
      icon="V"; device_label="Virtual Headphones"; dev_color="$VHEADPHONES_COLOR" ;;
    v_speakers|*v_speakers*) 
      icon="V"; device_label="Virtual Speakers"; dev_color="$VSPEAKERS_COLOR" ;;
    *headphones*) 
      icon=""; device_label="Headphones"; dev_color="$HEADPHONES_COLOR" ;;
    *speakers*) 
      icon=""; device_label="Speakers"; dev_color="$SPEAKERS_COLOR" ;;
    *hdmi*) 
      icon="H"; device_label="HDMI"; dev_color="$SPEAKERS_COLOR" ;;
    *) 
      icon=""; device_label="Device"; dev_color="" ;;
  esac

  # 3. Handle Muted vs. Unmuted states
  if [ "$muted" = "yes" ]; then
    final_text=""
    tooltip_text="$device_label Muted"
    percentage_val=0
    class_val="muted"
  else
    # --- This is where USE_PANGO is involved ---
    if [ "$USE_PANGO" = "true" ]; then
      # Choose which percentage to use for alpha: prefer heard_volume if provided
      local alpha_pct=${heard_volume:-$volume}
      # Calculate alpha: Start at MIN_ALPHA, scale up to 100 based on chosen percentage
      local alpha=$(( MIN_ALPHA + (alpha_pct * (100 - MIN_ALPHA) / 100) ))
      
      if [ -n "$dev_color" ]; then
        final_text="<span alpha='${alpha}%' color='${dev_color}'>$icon</span>"
      else
        final_text="<span alpha='${alpha}%'>$icon</span>"
      fi
    else
      final_text="$icon"
    fi

    # Tooltip: if this is a virtual device (node_name contains "effect_input.") show only the part after the last dot
    if printf '%s\n' "$node_name" | grep -q "effect_input\."; then
      # Extract substring after last dot
      short_name="${node_name##*.}"
      tooltip_text="$short_name ${volume}%"
    else
      tooltip_text="$device_label ${volume}%"
    fi

    percentage_val="$volume"
    class_val="$device_type"
  fi

  # --- Optional Dunst Notification ---
  if [ "$DUNST_NOTIFY_VOLUME" = "true" ]; then
    if [ "$muted" = "yes" ]; then
      dunstify -a "Volume" -r 2593 -u low -t 1500 "Muted" -i audio-volume-muted-symbolic
    else
      dunstify -a "Volume" -r 2593 -u low -t 500 -h int:value:"$volume" "${tooltip_text}"
    fi
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
    awk -v id="$1" 'BEGIN{RS="\n\n";FS="\n"} $0 ~ ("object.id[[:space:]]*=[[:space:]]*\"" id "\"") || $0 ~ ("object.serial[[:space:]]*=[[:space:]]*\"" id "\"") {print; exit}' "$TMP_FILE"
}

get_active_port_from_block() { awk -F': ' '/Active Port:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$1"; }

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
    driver_id=$(awk -F'=' '/node.driver-id/ {gsub(/"/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$def_block")
    if [ -z "$def_block" ]; then
        output_json "default" "${volume:-0}" "${muted:-no}" "$node_name"
        return
    fi

    # --- 1. MODE DETECTION (Simplified) ---
    if [[ "$node_name" == effect_input.* ]]; then
        is_v="yes"
    else
        is_v="no"
    fi

    # --- 2. PORT IDENTIFICATION ---
    port=$(get_active_port_from_block "$def_block")

    # If it's a virtual sink with no direct port, look at the parent hardware
    if [ "$is_v" = "yes" ] && [ -z "$port" ]; then
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
	*hdmi*)
            base_type="hdmi" 
            ;;
        *speaker*|*surround*|*lineout*|*analog-output*)
            base_type="speakers" 
            ;;
        *)
            # Final fallback scan for any active physical headphones
            phys_has_hp=$(awk 'BEGIN{RS="\n\n";FS="\n";IGNORECASE=1} {name=""; for(i=1;i<=NF;i++) if($i ~ /^Name: /){sub(/^Name: /,"",$i); name=$i} if(name!="" && tolower(name) !~ /virtual|surround|effect_input.|atmos/){ for(i=1;i<=NF;i++) if($i ~ /Active Port:/ && tolower($i) ~ /headphones/ && tolower($i) !~ /mic/){print "yes"; exit}} }' "$TMP_FILE")
            [ "$phys_has_hp" = "yes" ] && base_type="headphones" || base_type="speakers" || base_type="hdmi"
            ;;
    esac

    # --- 4. FINAL TYPE ASSIGNMENT ---
    if [ "$is_v" = "yes" ]; then
        device_type="v_$base_type"
    else
        device_type="$base_type"
    fi

    # Compute heard_volume: if this is a virtual sink, try to get the underlying physical sink's volume
    heard_volume=""
    phys_vol=""
    
    if [ "$is_v" = "yes" ]; then
        # Try to get driver id from the virtual sink block (node.driver-id)
        if [ -n "$driver_id" ]; then
            # Look up the underlying block by object.id or object.serial in the cached TMP_FILE
            under_block=$(awk -v id="$driver_id" 'BEGIN{RS="\n\n";FS="\n"} $0 ~ ("object.id[[:space:]]*=[[:space:]]*\"" id "\"") || $0 ~ ("object.serial[[:space:]]*=[[:space:]]*\"" id "\"") {print; exit}' "$TMP_FILE")
    
            if [ -n "$under_block" ]; then
                # Try to extract a usable sink name: prefer the top-level "Name:" but fall back to node.name = "..."
                phys_name=$(awk -F': ' '
                    /^Name:[[:space:]]*/ { gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit }
                    /node.name[[:space:]]*=/ { sub(/.*=[[:space:]]*"/,"",$0); sub(/".*/,"",$0); gsub(/^[ \t]+|[ \t]+$/,"",$0); print $0; exit }
                ' <<<"$under_block")
    
                if [ -n "$phys_name" ]; then
                    # Prefer querying pactl for the physical sink volume (most reliable)
                    phys_vol=$(pactl get-sink-volume "$phys_name" 2>/dev/null | awk '{print $5}' | sed 's/%//')
                    # If pactl failed, try to parse the Volume: line from the under_block
                    if [ -z "$phys_vol" ]; then
                        phys_vol=$(awk -F'/' '/Volume:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); sub(/%/,"",$2); print $2; exit}' <<<"$under_block")
                    fi
                fi
            fi
        fi
    
        # Fallback: pick first non-effect_input sink from pactl list short sinks
        if [ -z "$phys_vol" ]; then
            fallback_phys=$(pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -v -E '^effect_input\.' | head -n1)
            if [ -n "$fallback_phys" ]; then
                phys_vol=$(pactl get-sink-volume "$fallback_phys" 2>/dev/null | awk '{print $5}' | sed 's/%//')
            fi
        fi
    
        # Final fallback assume 100% so heard_volume is always computed
        phys_vol=${phys_vol:-100}
    
        # Compute effective heard volume (integer math)
        heard_volume=$(( (volume * phys_vol) / 100 ))
    fi
    
    # If heard_volume is empty, output_json will use the sink's own volume for alpha
    output_json "$device_type" "${volume:-0}" "${muted:-no}" "$node_name" "${heard_volume:-}"
}

# --- 6. Execution ---
# Print the status once immediately on startup
print_status

# Enter infinite loop waiting for audio events
pactl subscribe 2>/dev/null | grep --line-buffered -E "sink|server" | while read -r event; do
    print_status
done
