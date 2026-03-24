# Auto-generate hyprsunset configuration

This example uses `weather.sh` to fetch exact sunrise and sunset times (in 24h format via Open-Meteo) and mathematically generates a 1-hour smooth screen gamma transition for `hyprsunset`.

## Prerequisites

1. **Install hyprsunset**: Make sure `hyprsunset` is installed on your system (e.g., via your package manager).
2. **Autostart in Hyprland**: Since systemd user services often lack the necessary Wayland environment variables at boot, it is highly recommended to start `hyprsunset` natively via Hyprland. Add this to your `~/.config/hypr/hyprland.conf`:
   ```ini
   exec-once = hyprsunset
   ```

## Installation

1. Copy `update-hyprsunset.sh` to your hyprland config folder (e.g., `~/.config/hypr/`) and make it executable:
   ```bash
   cp update-hyprsunset.sh ~/.config/hypr/
   chmod +x ~/.config/hypr/update-hyprsunset.sh
   ```
2. Edit `~/.config/hypr/update-hyprsunset.sh` and make sure `WEATHER_SCRIPT` points to the correct path of your `weather.sh`.
3. Copy the systemd units to your user systemd folder:
   ```bash
   mkdir -p ~/.config/systemd/user/
   cp update-hyprsunset.service ~/.config/systemd/user/
   cp update-hyprsunset.timer ~/.config/systemd/user/
   ```
4. Reload systemd and enable the timer to run daily at 03:00 AM:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now update-hyprsunset.timer
   ```
   *(Note: The timer will automatically run the script in the background every night, fetching the new times for the upcoming day and reloading the config).*

### Optional Midday brightness boost

You can provide a click-to-toggle daylight profile that restarts hyprsunset with stronger gamma/temperature for bright midday conditions. Place this in your bar's Backlight or display-control module.

Example:
```json
"on-click": "/bin/sh -c '/usr/bin/pkill -x hyprsunset >/dev/null 2>&1; sleep 2; setsid /usr/bin/hyprsunset --gamma_max 100 >/dev/null 2>&1 &'",
"on-click-right": "/bin/sh -c '/usr/bin/pkill -x hyprsunset >/dev/null 2>&1; sleep 2; setsid /usr/bin/hyprsunset --gamma_max 175 --gamma 175 --temperature 6500 >/dev/null 2>&1 &'"
```

*(Note: adjust the hyprsunset path if needed and tweak --gamma_max, --gamma, and --temperature to taste).*
