# Auto-generate hyprsunset configuration

This example uses `weather.sh` to fetch exact sunrise and sunset times (in 24h format via Open-Meteo) and mathematically generates a 1-hour smooth screen gamma transition for `hyprsunset`.

## Prerequisites

1. **Install hyprsunset**: Make sure `hyprsunset` is installed on your system (e.g., via your package manager).
2. **Setup hyprsunset service**: This automation script assumes you are running `hyprsunset` as a systemd user service so it can restart it seamlessly. Make sure `hyprsunset.service` exists and is enabled:
   ```bash
   systemctl --user enable --now hyprsunset.service
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
