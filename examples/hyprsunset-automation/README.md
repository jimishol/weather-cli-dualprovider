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
"on-click": "~/.config/waybar/scripts/toggle-hyprsunset.sh OFF",
"on-click-right": "~/.config/waybar/scripts/toggle-hyprsunset.sh 175",
"on-scroll-up": "brightnessctl set +5%",
"on-scroll-down": "brightnessctl set 5%-"
```

**Notes**
- The toggle script reads the low value (`max-gamma`) from your `hyprsunset.conf` (fallback `100`) and uses an environment variable `BOOST_BRIGHT` (default `175`) unless a numeric argument is provided.
- The script uses a short, non‑blocking wait loop (small `usleep` intervals) instead of a fixed `sleep` to ensure `hyprsunset` has exited before restarting it.
- Use BOOST when the hardware maximum brightness still seems dim; use OFF to kill hyprsunset for true‑color movie watching at night.
---

### Click behavior and state model

This setup uses a simple three‑state model stored in a state file (e.g., `/tmp/hyprsunset_state`):

- **NORMAL** — `hyprsunset` running with time profiles (default).
- **BOOST** — `hyprsunset` running with a forced brighter profile (e.g., `--gamma_max 175`).
- **OFF** — user‑forced kill of `hyprsunset` for true color (movie mode).

**Important UX detail (minimal change):** when you force OFF via the left‑click handler, the toggle script writes **`NORMAL`** into the state file. This makes the next right‑click immediately start **BOOST** (no dead click where OFF and NORMAL look identical during daytime). The left‑click still kills `hyprsunset` so the screen is truly off from hyprsunset’s control, but the stored state is set to NORMAL to keep the toggle responsive.

---

### Files referenced

- **Waybar config snippet** (use the handlers shown above):
```json
"on-click": "~/.config/waybar/scripts/toggle-hyprsunset.sh OFF",
"on-click-right": "~/.config/waybar/scripts/toggle-hyprsunset.sh 175",
```
- **Toggle script**: `~/.config/waybar/scripts/toggle-hyprsunset.sh` (keeps state in `/tmp/hyprsunset_state`, reads `max-gamma` from `~/.config/hypr/hyprsunset.conf`, accepts `OFF`, `NORMAL`, or a numeric boost argument, and uses `BOOST_BRIGHT` env var as default).
