### WirePlumber Waybar Module Script

**wireplumber_label.sh** — A lightweight, standalone Waybar module that intelligently identifies your PipeWire sinks. It detects whether a sink is **virtual** or **physical**, distinguishes between **headphones** and **speakers**, and provides a seamless JSON output for real-time Waybar updates.

---

### Features
* **Dynamic Opacity (Glow)**: Icons fade/glow based on volume level using Pango markup (requires `format: {}` in Waybar config).
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

#### Note on the Right-Click Action:
* **Virtual Filter Users**: Use the example above (`toggle_sink`) to swap between hardware and software filters (Atmos/Convolver).
* **Hardware Profile Users**: If you don't use virtual sinks, replace `on-click-right` with your system sound panel to switch hardware profiles (e.g., Stereo vs 5.1):
  `"on-click-right": "env XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"`

---

### Usage & Troubleshooting
* **Icon Fading**: To adjust or disable the fading effect, edit the variables at the top of the script:
    * `USE_PANGO=true`: Enables/disables the glow effect.
    * `MIN_ALPHA=30`: Sets the minimum icon visibility at 0% volume.
* **Manual Test**: Run the script in a terminal to verify the JSON output:
    `~/.config/waybar/scripts/wireplumber_label.sh`
* **Toggle Test**: Test the sink switcher manually by running:
    `~/.config/waybar/scripts/wireplumber_label.sh toggle_sink`
* **Desktop Fallback**: If Right-Click does nothing, it is because no virtual sink was found. Use the `gnome-control-center` fallback mentioned above.
* **Icon Logic**: If your device is 4.1 or virtual, a **V** label appears. If sound stops when plugging in headphones on a surround system, use the sound panel to set the profile to "Analog Stereo."

---

### About PipeWire Filter Chains
This script is particularly useful for users running **PipeWire filter-chain convolvers**. Such setups often cause standard volume modules to misclassify devices or fail to detect port changes in non-English locales. 

**Performance Note**: Software-based convolution can be CPU-intensive. Use the toggle to switch back to the physical hardware sink for a direct signal path if you notice audio jitter during high-load tasks.
