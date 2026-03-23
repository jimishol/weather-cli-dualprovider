#!/usr/bin/env bash
# wireplumber_label.sh
# One-shot action handler: perform action and exit when called with args.
# When called with no args, run in continuous event-driven mode for Waybar.

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
    *) ;; # unknown action -> fall through
  esac
fi

# --- 2. JSON output function ---
output_json() {
  local device_type="$1"
  local volume="$2"
  local muted="$3"
  local node_name="$4"

  case "$device_type" in
    v_headphones|*v_headphones*) icon="V"; device_label="Virtual Headphones" ;;
    v_speakers|*v_speakers*)     icon="V"; device_label="Virtual Speakers" ;;
    *headphones*)                icon=""; device_label="Headphones" ;;
    *speakers*)                  icon=""; device_label="Speakers" ;;
    *)                           icon=""; device_label="Device" ;;
  esac

  node_name=${node_name//%/}

  if ! [[ "$volume" =~ ^[0-9]+$ ]]; then
    volume=${volume%%.*}
    volume=${volume:-0}
  fi

  if [ "$muted" = "yes" ]; then
    jq -nc --arg text "" \
          --arg tooltip "$device_label Muted" \
          --arg class "muted" \
          --arg device "$device_label" \
          --argjson percentage 0 \
          '{text: $text, tooltip: $tooltip, class: $class, device: $device, percentage: $percentage}'
  else
    jq -nc --arg text "$icon" \
          --arg tooltip "$device_label ${volume}%" \
          --arg class "$device_type" \
          --arg device "$device_label" \
          --argjson percentage "$volume" \
          '{text: $text, tooltip: $tooltip, class: $class, device: $device, percentage: $percentage}'
  fi
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
    awk 'BEGIN{IGNORECASE=1} /node.virtual[[:space:]]*=/ { if(tolower($0) ~ /node.virtual[[:space:]]*=[[:space:]]*"true"/) {print "yes"; exit} }
         /node.description[[:space:]]*=/ { if(tolower($0) ~ /virtual|surround|atmos/) {print "yes"; exit} }' <<<"$1"
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

    device_type="default"

    if [ "$(is_block_virtual "$def_block")" = "yes" ]; then
        driver_id=$(awk -F'=' '/node.driver-id/ {gsub(/"/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$def_block")
        if [ -n "$driver_id" ]; then
            under_block=$(get_block_by_objectid "$driver_id")
            port=$(get_active_port_from_block "$under_block")
            case "$port" in *headphones*) device_type="v_headphones" ;; *speaker*) device_type="v_speakers" ;; esac
            
            if [ "$device_type" = "default" ]; then
                phys_has_headphones=$(awk 'BEGIN{RS="\n\n";FS="\n";IGNORECASE=1} {name=""; for(i=1;i<=NF;i++) if($i ~ /^Name: /){sub(/^Name: /,"",$i); name=$i} if(name!="" && tolower(name) !~ /virtual|surround|atmos/){ for(i=1;i<=NF;i++) if($i ~ /Active Port:/ && tolower($i) ~ /headphones/){print "yes"; exit}} }' "$TMP_FILE")
                [ "$phys_has_headphones" = "yes" ] && device_type="v_headphones" || device_type="v_speakers" # Corrected: separate command
            fi
        else
            port=$(get_active_port_from_block "$def_block")
            case "$port" in *headphones*) device_type="v_headphones" ;; *speaker*) device_type="v_speakers" ;; esac
            
            if [ "$device_type" = "default" ]; then
                phys_has_headphones=$(awk 'BEGIN{RS="\n\n";FS="\n";IGNORECASE=1} {name=""; for(i=1;i<=NF;i++) if($i ~ /^Name: /){sub(/^Name: /,"",$i); name=$i} if(name!="" && tolower(name) !~ /virtual|surround|atmos/){ for(i=1;i<=NF;i++) if($i ~ /Active Port:/ && tolower($i) ~ /headphones/){print "yes"; exit}} }' "$TMP_FILE")
                [ "$phys_has_headphones" = "yes" ] && device_type="v_headphones" || device_type="v_speakers" # Corrected: separate command
            fi
        fi
    else
        port=$(get_active_port_from_block "$def_block")
        case "$port" in
            *headphones*) device_type="headphones" ;;
            *speaker*)    device_type="speakers" ;;
        esac
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
