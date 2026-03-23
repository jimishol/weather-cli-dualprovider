### WirePlumber Waybar module script

**wireplumber_label.sh** — A small Waybar module script that detects whether the default PipeWire sink is **virtual** or **physical**, distinguishes **headphones** vs **speakers**, emits a single JSON object for Waybar, and supports click and scroll actions for volume and mute control.

> **Note:** This example is not related to the weather CLI functionality. It is a standalone Waybar helper script included in this repository for convenience and easy linking from a Show & Tell discussion.

---

### Features
- **Virtual vs physical sink detection** using `pactl list sinks` and `node.driver-id` tracing.  
- **Headphones vs speakers** inference for both virtual and physical sinks.  
- **JSON output** suitable for Waybar `exec` modules with `return-type: json`.  
- **Click and scroll actions**: mute toggle, open sound settings, volume up/down.  
- **Event driven** updates via `pactl subscribe` for near real‑time changes.

---

### Requirements
- **Runtime tools**: `pactl`, `wpctl`, `jq`, `awk`, `sed`, `grep`.  
- **Waybar** configured to run the script as a custom module.  
- **Note**: The script itself does not require GNOME. The **right‑click action** in the example opens GNOME Sound Settings using `gnome-control-center sound`; change that command if you use a different desktop settings tool.

---

### Install
Copy the example into your Waybar scripts folder and make it executable:
```bash
mkdir -p ~/.config/waybar/scripts
cp examples/wireplumber_label/wireplumber_label.sh ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/wireplumber_label.sh
```

---

### Waybar config snippet
Add this to your `~/.config/waybar/config` under the modules you want:
```json
"custom/audio": {
  "exec": "~/.config/waybar/scripts/wireplumber_label.sh",
  "return-type": "json",
  "format": "{}",
  "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  "on-click-right": "env XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound",
  "on-scroll-up": "~/.config/waybar/scripts/wireplumber_label.sh up 10",
  "on-scroll-down": "~/.config/waybar/scripts/wireplumber_label.sh down 10",
  "tooltip": true
}
```
**Tip**: Replace the `on-click-right` command if you do not use GNOME.

---

### Usage and debugging
- Run the script manually to inspect output and errors:
```bash
~/.config/waybar/scripts/wireplumber_label.sh
```
- If Waybar shows nothing, check that `pactl` and `wpctl` work in your session and that `jq` is installed.  
- The script falls back to a safe default JSON object if `pactl` output is missing or unexpected.

---

### About PipeWire filter‑chain convolver
The script itself does **not** install or require any PipeWire filter; it only reads PipeWire/WirePlumber state and labels sinks for Waybar. It is useful when you run a **PipeWire filter‑chain convolver** (a virtual sink) because that setup can cause sinks to be misclassified or collapsed. 

**Important:** a filter‑chain convolver performs convolution and resampling in software and can be CPU‑intensive. On low‑power systems or with heavy sources (for example large MIDI soundfonts or many simultaneous streams) you may see audio jitter, dropouts, or increased latency. If you suspect the filter is causing problems, change the default sink to a hardware (non‑filtered) sink and move active streams to it.

---

### Troubleshooting notes
- Behavior may vary across PipeWire and WirePlumber versions; this script is a pragmatic workaround for misclassified sinks.  
- If device classification looks wrong, run `pactl list sinks`, compare its output to what the script inspects.

---

### License
This example inherits the repository license **GPL‑3.0**.

---

### Where to find it
**Path in this repo**  
`examples/wireplumber_label/wireplumber_label.sh`  
`examples/wireplumber_label/README.md`

**Direct link**  
https://github.com/jimishol/weather-cli-dualprovider/tree/main/examples/wireplumber_label
