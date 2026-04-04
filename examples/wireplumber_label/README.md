### WirePlumber Waybar Module Script

**wireplumber_label.sh** — A lightweight, standalone Waybar module that intelligently identifies your PipeWire sinks. It detects whether a sink is **virtual** or **physical**, distinguishes between **headphones** and **speakers**, and provides a seamless JSON output for real-time Waybar updates.

---

### Features
* **Virtual vs. Physical Detection**: Uses `pactl list sinks` and `node.driver-id` tracing for pinpoint device identification.
* **Native Sink Toggling**: Swap between physical hardware and virtual filters (like Surround/Atmos) with a right-click—no external GUI or GNOME dependencies required.
* **Dynamic Port Inference**: Automatically detects active ports (Headphones vs. Speakers) for both hardware and virtual devices.
* **JSON Integration**: Designed specifically for Waybar `exec` modules with full support for `return-type: json`.
* **Event-Driven Logic**: Utilizes `pactl subscribe` to update the UI instantly when volume changes or devices are swapped.

---

### Requirements
* **Runtime tools**: `pactl`, `wpctl`, `jq`, `awk`, `sed`, `grep`.
* **Wayland/Waybar**: Compatible with any Wayland compositor (Hyprland, Sway, etc.).
* **Desktop Agnostic**: Does not require GNOME, KDE, or any specific desktop environment.

---

### Installation
Move the script to your config folder and ensure it is executable:

```bash
mkdir -p ~/.config/waybar/scripts
cp examples/wireplumber_label/wireplumber_label.sh ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/wireplumber_label.sh
```

---

### Waybar Configuration
Add the following block to your `~/.config/waybar/config` (or `config.jsonc`). 

**Note:** Ensure you use the full path to the script to avoid environment issues.

```json
"custom/audio": {
    "exec": "~/.config/waybar/scripts/wireplumber_label.sh",
    "return-type": "json",
    "format": "{}",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-click-right": "~/.config/waybar/scripts/wireplumber_label.sh toggle_sink",
    "on-scroll-up": "~/.config/waybar/scripts/wireplumber_label.sh up 5",
    "on-scroll-down": "~/.config/waybar/scripts/wireplumber_label.sh down 5",
    "tooltip": true
}
```

---

### Usage & Troubleshooting
* **Manual Test**: Run the script in a terminal to verify the JSON output:
    `~/.config/waybar/scripts/wireplumber_label.sh`
* **Toggle Test**: Test the sink switcher manually by running:
    `~/.config/waybar/scripts/wireplumber_label.sh toggle_sink`
* **No Output?**: Confirm `pactl` and `jq` are installed and that your PipeWire session is active.

---

### About PipeWire Filter Chains
This script is particularly useful for users running **PipeWire filter-chain convolvers** (virtual sinks). Such setups often cause standard volume modules to misclassify devices or collapse them into a single entry. 

**Important Performance Note:** Software-based convolution and resampling can be CPU-intensive. If you experience audio jitter or high latency on low-power systems, use the **Right-Click toggle** to switch back to the physical (hardware) sink for a direct, low-overhead signal path.
