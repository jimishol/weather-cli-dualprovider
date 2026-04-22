### WirePlumber Waybar Module Script

**wireplumber_label.sh** — A compact Waybar module script that detects PipeWire sinks, distinguishes **virtual** vs **physical**, chooses **headphones** vs **speakers** icons, and emits JSON for Waybar. The script also computes the **heard** volume for virtual filters so icon opacity reflects what you actually hear while the tooltip shows the virtual sink percent.

### Features
* **Dynamic Opacity (Optional)**: Icons fade/glow based on volume level using Pango markup (requires `format: {}` in Waybar config).
* **Dunst Volume Notifications (Optional)**: Optional integration with `dunstify` to display sleek, stackable volume progress bars.
* **Virtual vs. Physical Detection**: Uses `pactl list sinks` and `node.driver-id` tracing for pinpoint device identification.
* **Native Sink Toggling**: Swap between physical hardware and virtual filters directly via the script.
* **Language Agnostic**: Uses technical node properties, ensuring icons work correctly on any system locale.
* **Dynamic Port Inference**: Automatically detects active ports (Headphones vs. Speakers) for both hardware and virtual devices.
* **Event-Driven Logic**: Utilizes `pactl subscribe` for instant UI updates.

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
To enable the **dynamic opacity (fading)** effect, ensure your `config` file includes `"format": "{}"`. This allows Waybar to parse the Pango markup used for the icons.

**Full Module Example:**
```json
"custom/audio": {
  "exec": "~/.config/waybar/scripts/wireplumber_label.sh",
  "return-type": "json",
  "format": "{}",
  "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  "on-click-right": "~/.config/waybar/scripts/wireplumber_label.sh toggle_sink",
  "on-scroll-up": "~/.config/waybar/scripts/wireplumber_label.sh up 10",
  "on-scroll-down": "~/.config/waybar/scripts/wireplumber_label.sh down 10",
  "tooltip": true
}
```

**Notes**
- **`format: "{}"`** is required to render Pango `<span alpha='...'>` markup used for icon fading.
- If you see raw `<span ...>` text, set `USE_PANGO="false"` in the script or remove `"format": "{}"`.

---

### Dunst Configuration (Optional)
If you enable `DUNST_NOTIFY_VOLUME="true"` in the script, add the following to your `dunstrc` (usually `~/.config/dunst/dunstrc`) to enable progress bars and prevent notification flooding:

```ini
[stack-volumes]
    appname = "Volume"
    set_stack_tag = "volume"
    history_ignore = true

# In your [global] section, ensure progress bars are enabled:
progress_bar = true
progress_bar_height = 10
progress_bar_frame_width = 1
progress_bar_min_width = 150
progress_bar_max_width = 300
progress_bar_corner_radius = 0
```
---

### PipeWire Filter Naming and Examples

**Required pattern for deterministic detection**

For reliable virtual-sink detection and correct icon fading, name filter sinks like:

```conf
node.name = "effect_input.<SHORTNAME>"
```

**Why this matters**

- The script treats `node.name` values starting with **`effect_input.`** as virtual filter sinks.
- When a virtual sink is active the script attempts to find the mapped physical sink (via `node.driver-id` → `object.id`) and computes:

```
heard_volume = virtual_volume * physical_volume / 100
```

This makes the Waybar icon opacity reflect the audible level while the tooltip still shows the virtual sink percent.

**Minimal filter example**

```conf
capture.props = {
  node.name = "effect_input.IE200"
  media.class = Audio/Sink
  audio.channels = 8
}
playback.props = {
  node.name = "effect_input.IE200"
  node.passive = true
  audio.channels = 2
}
```

**Multiple filters**

- Give each filter a unique short name after `effect_input.` (e.g., `effect_input.DT990`, `effect_input.IE200`).
- The script cycles virtual sinks first when using the `toggle_sink` action.

**Fallback behavior**

- If `node.driver-id` mapping cannot be resolved, the script falls back to the first non-`effect_input.` sink found by `pactl list short sinks`.
- This preserves functionality on systems where mappings are missing or formatted differently.

---

### Usage & Troubleshooting
* **Icon Fading & Notifications**: Edit variables at the top of the script to customize:
    * `USE_PANGO="true"`: Enables/disables the glow effect. Set to "false" if you see raw <span alpha...> tags in your bar.
    * `MIN_ALPHA=30`: Sets the minimum icon visibility at 0% volume.
    * `DUNST_NOTIFY_VOLUME="false"`: Enables Dunst progress bar notifications. Set to "true" to opt-in (requires dunstify and the dunstrc rules below).
* **Manual Test**: Run the script in a terminal to verify the JSON output:
    `~/.config/waybar/scripts/wireplumber_label.sh`
* **Note on Right-Click**:
    * **Virtual Filter Users**: Use `toggle_sink` (as shown in the JSON example) to swap hardware/software filters.
    * **Hardware Users**: Replace `on-click-right` with your sound panel:
      `"on-click-right": "env XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"`
* **Icon Logic**: If your device is 4.1 or virtual, a **V** label appears. If sound stops when switching to headphones on surround systems, set the profile to "Analog Stereo" in your sound panel.

**If icon opacity does not match audible volume**

1. Confirm your filter has `node.name = "effect_input.<NAME>"`.
2. Confirm the physical sink block contains `object.id` or `object.serial`.
3. If you have multiple physical sinks, the fallback may pick a different device — prefer `node.driver-id` mapping.

---

### About PipeWire Filter Chains
This script is particularly useful for users running **PipeWire filter-chain convolvers**. Such setups often cause standard volume modules to misclassify devices or fail to detect port changes in non-English locales. 

**Performance Note**: Software-based convolution can be CPU-intensive. Use the toggle to switch back to the physical hardware sink for a direct signal path if you notice audio jitter during high-load tasks.
