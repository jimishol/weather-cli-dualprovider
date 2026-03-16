#!/usr/bin/env bash
# locales/weather.en.sh
# English locale for weather-cli-dualprovider
# LOCALE_VERSION helps detect incompatible changes
LOCALE_VERSION="1"

# WMO code → English description
declare -A DESC_FOR_WMO=(
  [0]="Clear" [1]="Mainly clear" [2]="Partly cloudy" [3]="Cloudy"
  [45]="Fog" [48]="Depositing rime fog"
  [51]="Light drizzle" [53]="Moderate drizzle" [55]="Dense drizzle"
  [56]="Freezing drizzle" [57]="Dense freezing drizzle"
  [61]="Light rain" [63]="Moderate rain" [65]="Heavy rain"
  [66]="Freezing rain" [67]="Heavy freezing rain"
  [71]="Light snow fall" [73]="Moderate snow fall" [75]="Heavy snow fall"
  [77]="Snow grains" [80]="Light shower" [81]="Moderate shower" [82]="Heavy shower"
  [85]="Light snow showers" [86]="Heavy snow showers"
  [95]="Thunderstorm" [96]="Thunderstorm with hail" [99]="Severe thunderstorm"
)

# Localized static labels used in tooltip and messages
LABEL_SUNRISE="Sunrise"
LABEL_SUNSET="Sunset"
LABEL_FEELS="Feels like"
LABEL_RAIN="Rain"
LABEL_PROVIDER_WTTR="wttr.in"
LABEL_PROVIDER_OPENMETEO="Open‑Meteo"
LABEL_UNKNOWN="Unknown"

# Optional: localized command help lines (used only in terminal mode)
HELP_TOGGLE_UNITS="Toggle wind units:   weather wind_mode && weather"
HELP_TOGGLE_PROVIDER="Toggle provider:      weather provider && weather"
