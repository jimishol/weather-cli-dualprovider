### WirePlumber Waybar Module Script

**wireplumber_label.sh** — A lightweight, standalone Waybar module that intelligently identifies your PipeWire sinks. It detects whether a sink is **virtual** or **physical**, distinguishes between **headphones** and **speakers**, and provides a seamless JSON output for real-time Waybar updates.

---

### Features
* **Virtual vs. Physical Detection**: Uses `pactl list sinks` and `node.driver-id` tracing for pinpoint device identification.
* **Native Sink Toggling**: Swap between physical hardware and virtual filters (like Surround/Atmos) directly via the script.
* **Language Agnostic**: Uses technical node properties (English) instead of localized descriptions, ensuring icons work correctly on Greek or other non-English system locales.
* **Dynamic Port Inference**: Automatically detects active ports (Headphones vs. Speakers) for both hardware and virtual devices.
* **Event-Driven Logic**: Utilizes `pactl subscribe` to update the UI instantly when volume changes or devices are swapped.

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
The configuration differs depending on whether you are using software filters (like Atmos/Convolver) or standard hardware profiles.

#### 1. Laptop / Virtual Filter Setup
If you use a software-based virtual sink, use the script to toggle it:
```json
"on-click-right": "~/.config/waybar/scripts/wireplumber_label.sh toggle_sink"
```

#### 2. Desktop / Hardware Profile Setup
If your machine does not use virtual filters (the `VIRTUAL_SINK` variable is empty), the script will simply log an error to the terminal. In this case, use your system settings to switch hardware profiles (e.g., Stereo vs. 4.1):
```json
"on-click-right": "env XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"
```

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

---

### Usage & Troubleshooting
* **Manual Test**: Run the script in a terminal to verify the JSON output:
    `~/.config/waybar/scripts/wireplumber_label.sh`
* **Toggle Test**: Test the sink switcher manually by running:
    `~/.config/waybar/scripts/wireplumber_label.sh toggle_sink`
* **Desktop Fallback**: If Right-Click does nothing on your Desktop, it is because no virtual sink was found. In this case, use the `gnome-control-center` command in your Waybar config instead. 
* **Icon Logic**: If your device is 4.1 or virtual, a **V** label appears. If sound stops when plugging in headphones on a surround system, use the sound panel to set the profile to "Analog Stereo."

---

### About PipeWire Filter Chains
This script is particularly useful for users running **PipeWire filter-chain convolvers** (virtual sinks). Such setups often cause standard volume modules to misclassify devices or fail to detect port changes in non-English locales. 

**Performance Note**: Software-based convolution can be CPU-intensive. Use the toggle to switch back to the physical hardware sink for a direct, low-overhead signal path if you notice audio jitter.
