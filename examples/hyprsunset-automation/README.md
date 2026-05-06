### Auto-generate hyprsunset configuration

This example uses **`weather.sh`** to fetch exact sunrise and sunset times (24h format via Open‑Meteo) and mathematically generates a 1‑hour smooth screen gamma transition for **`hyprsunset`**.

---

### Prerequisites

1. **Install hyprsunset**: Ensure `hyprsunset` is installed (via your package manager).
2. **Autostart in Hyprland**: Systemd user services often lack Wayland environment variables at boot. Start `hyprsunset` from Hyprland by adding this to `~/.config/hypr/hyprland.conf`:
```ini
exec-once = hyprsunset
```

---

### Installation

1. Copy `update-hyprsunset.sh` to your Hyprland config folder and make it executable:
```bash
cp update-hyprsunset.sh ~/.config/hypr/
chmod +x ~/.config/hypr/update-hyprsunset.sh
```
2. Edit `~/.config/hypr/update-hyprsunset.sh` and ensure `WEATHER_SCRIPT` points to your `weather.sh`.
3. Copy the systemd units to your user systemd folder:
```bash
mkdir -p ~/.config/systemd/user/
cp update-hyprsunset.service ~/.config/systemd/user/
cp update-hyprsunset.timer ~/.config/systemd/user/
```
4. Reload systemd and enable the timer to run daily at 03:00:
```bash
systemctl --user daemon-reload
systemctl --user enable --now update-hyprsunset.timer
```
*(The timer runs the script nightly to fetch the next day’s times and reload the config.)*

---

### Optional Midday brightness boost (Waybar integration)

You can add click‑to‑toggle actions that restart `hyprsunset` with a brighter profile for sunny midday conditions. Use a small toggle script (example: `~/.config/waybar/scripts/toggle-hyprsunset.sh`) so Waybar handlers remain simple and readable.

**Recommended Waybar handlers**
```json
"on-click": "~/.config/waybar/scripts/toggle-hyprsunset.sh ON_OFF",
"on-click-right": "~/.config/waybar/scripts/toggle-hyprsunset.sh 145",
"on-scroll-up": "brightnessctl -e2 -n2 set +2%",
"on-scroll-down": "brightnessctl -e2 -n2 set 2%-"
```

**Notes**
- The toggle script reads the low value (`max-gamma`) from your `hyprsunset.conf` (fallback `100`) and uses an environment variable `BOOST_BRIGHT` (default **145**) unless a numeric argument is provided.
- The script uses a short, non‑blocking wait loop (small `usleep` intervals) instead of a fixed `sleep` to ensure `hyprsunset` has exited before restarting it.
- Use **BOOST** when the hardware maximum brightness still seems dim; use **ON_OFF** to kill hyprsunset for true‑color movie watching at night.
---

### Click behavior and state model

This setup uses a simple three‑state model stored in a state file (e.g., `/tmp/hyprsunset_state`):

- **NORMAL** — `hyprsunset` running with time profiles (default).
- **BOOST** — `hyprsunset` running with a forced brighter profile (e.g., `--gamma_max 145`).
- **ON_OFF** — user‑toggle forced kill of `hyprsunset` for true color (movie mode) and normal hyprsunset.

**Important UX detail (minimal change):** when you kill hyprsunset via the left‑click handler, the toggle script writes **`NORMAL`** into the state file. This makes the next right‑click immediately start **BOOST** (no dead click where OFF and NORMAL look identical during daytime). The left‑click still kills `hyprsunset` so the screen is truly off from hyprsunset’s control, but the stored state is set to NORMAL to keep the toggle responsive.

---

### 🖥️ Visual Feedback (Waybar Integration)

Since the automation runs silently via systemd timers, you can add a custom Waybar module to monitor the current temperature/gamma and provide manual overrides.

#### 1. Set Up the Tooltip Script
The `gamma_tooltip.sh` script is provided in this directory. Move or link it to your Waybar scripts directory to enable the module:

```bash
# Create the directory if it doesn't exist
mkdir -p ~/.config/waybar/scripts/

# Copy the script from this folder and make it executable
cp gamma_tooltip.sh ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/gamma_tooltip.sh
```

> **Note:** This script reads the `hyprsunset` socket directly to provide real-time feedback on the current color temperature and automation state.

#### 2. Waybar Configuration
The following configuration provides a dedicated custom module that displays the current gamma state directly from the automation script.

```jsonc
"custom/backlight": {
    "format": "{text}",
    "return-type": "json",
    "interval": 600, 
    "exec": "~/.config/waybar/scripts/gamma_tooltip.sh",
    "on-click": "~/.config/waybar/scripts/toggle-hyprsunset.sh ON_OFF",
    "on-click-right": "~/.config/waybar/scripts/toggle-hyprsunset.sh 145",
    "tooltip": true
}
```

#### Integration with Native Backlight Module
Alternatively, you can integrate the automation into the native Waybar `backlight` module. This allows you to control hardware brightness and hyprsunset transitions in one place, using notifications to provide feedback on state changes.

```jsonc
  "backlight": {  
      "format": "{icon}",  
      "tooltip-format": "{percent}% {icon}",  
      "format-icons": ["", "", "", ""],
      // Actions: Press to toggle, Release to notify status
      "on-click": "~/.config/waybar/scripts/toggle-hyprsunset.sh ON_OFF",
      "on-click-release": "sleep 1; notify-send -a \"Gamma\" -u low \"hyprsunset Toggle\" \"$(~/.config/waybar/scripts/gamma_tooltip.sh | jq -r '.tooltip')\"",  
      "on-click-right": "~/.config/waybar/scripts/toggle-hyprsunset.sh 145",
      "on-click-right-release": "sleep 1; notify-send -a \"Gamma\" -u low \"Gamma Boost Toggle\" \"$(~/.config/waybar/scripts/gamma_tooltip.sh | jq -r '.tooltip')\"",  
      "on-click-middle": "notify-send -a \"Gamma\" -u low \"Color Status\" \"$(~/.config/waybar/scripts/gamma_tooltip.sh | jq -r '.tooltip')\"",
      // Hardware Brightness Control
      "on-scroll-up": "brightnessctl -e2 -n2 set +2%",  
      "on-scroll-down": "brightnessctl -e2 -n2 set 2%-"  
  },
```

The following to your `dunstrc` (usually `~/.config/dunst/dunstrc`) prevent notification flooding:

```ini
[stack-gamma_tooltip]
    appname = "Gamma"
    set_stack_tag = "gamma"
    history_ignore = true
```

---

### Files referenced

- **Waybar configuration**: Include the `custom/backlight` block in your Waybar config.
- **Monitor script**: `~/.config/waybar/scripts/gamma_tooltip.sh` (The JSON-provider for the Waybar tooltip).
- **Toggle script**: `~/.config/waybar/scripts/toggle-hyprsunset.sh` (The state-machine that manages the `hyprsunset` process).
- **Automation logic**: `~/.config/hypr/update-hyprsunset.sh` (The bridge between `weather.sh` and your configuration).
- **State file**: `/tmp/hyprsunset_state` (Used to track whether you are in `NORMAL`, `BOOST`, or `OFF` mode).
