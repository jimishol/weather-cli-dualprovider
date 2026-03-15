# weather-cli-dualprovider

A portable Bash weather script for Waybar and CLI with two interchangeable providers, emoji icons, Greek localization, and flexible wind units.

## Features
- **Dual providers**: Open‑Meteo and wttr.in with automatic fallback on API errors.  
- **Why dual providers**: Open‑Meteo generally provides **more accurate forecasts**, while **wttr.in** can deliver **more accurate current conditions** when there is a nearby weather station. This is the reason for the dual‑provider design.  
- **Emoji icons** for quick visual weather cues.  
- **Greek localization** for Open‑Meteo descriptions.  
- **Wind units**: **Beaufort**, **km/h**, and **knots** (displayed as **kt**).  
- **Wind direction arrows** using a 16‑point compass.  
- **Waybar JSON output** compatible with Waybar modules.  
- **Full CLI compatibility**: works in desktop Linux, Termux, TTY, SSH, and headless environments.  
- **Forecast tooltip** with sunrise/sunset, min/max, feels like, and rain probability.  
- **Per‑user persistent state** stored under `~/.cache/weather` by default.

## Requirements
- **bash**, **curl**, **jq**, **awk**, **date** (GNU coreutils).  
- Waybar for JSON module integration (optional).  
- Ensure the script is executable: `chmod +x /path/to/weather.sh`.

## Installation
1. Place the script where you prefer (example uses Waybar scripts folder):
```bash
mkdir -p ~/.config/waybar/scripts
cp weather.sh ~/.config/waybar/scripts/weather.sh
chmod +x ~/.config/waybar/scripts/weather.sh
```
2. The script creates and uses a per‑user state directory by default:
```bash
TMPDIR="$HOME/.cache/weather"
mkdir -p "$TMPDIR"
```
3. Default provider and wind mode are initialized on first run:
```bash
DEFAULT_PROVIDER="wttr"
DEFAULT_WIND="bft"
```

## Waybar Configuration
Add a custom module to your Waybar config (use absolute paths if you prefer):

```json
"custom/weather": {
  "format": "{}",
  "interval": 600,
  "exec": "~/.config/waybar/scripts/weather.sh",
  "return-type": "json",
  "on-click": "~/.config/waybar/scripts/weather.sh provider",
  "on-click-right": "~/.config/waybar/scripts/weather.sh wind_mode"
}
```

**CSS example**
```css
#custom-weather {
  padding: 0 10px;
  color: #87ceeb;
  font-weight: bold;
}
```

## Usage
- **Show tooltip / Waybar JSON**:
```bash
/path/to/weather.sh
```
- **Toggle provider** (wttr.in ↔ Open‑Meteo):
```bash
/path/to/weather.sh provider
```
- **Cycle wind units** (km/h → Beaufort → knots → km/h):
```bash
/path/to/weather.sh wind_mode
```
- **Alias example** (optional, for CLI convenience):
```bash
alias weather="cal -3 && echo '\n' && ~/.config/waybar/scripts/weather.sh"
```

## Configuration
Edit the top of the script to change defaults:
- **DEFAULT_PROVIDER** — `"wttr"` or `"open-meteo"`.  
- **DEFAULT_WIND** — `"bft"`, `"knots"`, or `"kmh"`.  
- **FORECAST_DAYS** — number of future days shown in tooltip (Open‑Meteo only).  
- **LAT** and **LON** — coordinates for Open‑Meteo queries.

> **From the script:**  
> `# Default Provider as "wttr" or "open-meteo"`  
> `# Provider's wind_mode between "bft", "knots" or "kmh"`

## Implementation Notes
- **Unit abbreviation**: knots are displayed as **kt** to follow meteorological conventions.  
- **State files**: the script stores `weather_provider` and `weather_mode` in the per‑user state directory (default `~/.cache/weather`) so Waybar and CLI runs share the same state.  

## License 📝

This project is licensed under the **GNU General Public License v3.0**.  
You can find the full license text in the [LICENSE](LICENSE) file.
