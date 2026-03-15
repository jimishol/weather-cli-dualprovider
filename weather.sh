#!/usr/bin/env bash

# --- CONFIG ---

# How many FUTURE days to show in the tooltip? (Open-Meteo only. wttr.in max is 2)
FORECAST_DAYS=3

# Coordinates for Open-Meteo (Default: Chios, Greece)
LAT="38.3678"
LON="26.1361"

TERMINAL_MODE=false
if [[ -t 1 ]]; then
  TERMINAL_MODE=true
fi

TMPDIR="$HOME/.cache/weather"
mkdir -p "$TMPDIR"
PROVIDER_STATEFILE="$TMPDIR/weather_provider"

# Provider's toggle between "wttr" or "open-meteo"
if [[ ! -f $PROVIDER_STATEFILE ]]; then echo "wttr" > "$PROVIDER_STATEFILE"; fi

STATEFILE="$TMPDIR/weather_mode"   # remembers whether to show km/h or Bft
if [[ ! -f $STATEFILE ]]; then echo "bft" > "$STATEFILE"; fi

# If called with "toggle", switch mode and exit
if [[ "$1" == "toggle" ]]; then
  mode=$(<"$STATEFILE")
  if [[ "$mode" == "kmh" ]]; then
    echo "bft" > "$STATEFILE"
  else
    echo "kmh" > "$STATEFILE"
  fi
  exit 0
fi

mode=$(<"$STATEFILE")

# If called with "provider", toggle weather provider and exit
if [[ "$1" == "provider" ]]; then
  provider=$(<"$PROVIDER_STATEFILE")
  if [[ "$provider" == "wttr" ]]; then
    echo "open-meteo" > "$PROVIDER_STATEFILE"
  else
    echo "wttr" > "$PROVIDER_STATEFILE"
  fi
  exit 0
fi

WEATHER_PROVIDER=$(<"$PROVIDER_STATEFILE")

# --- 1) Weather code → emoji ---
# Liberally spaced out to strictly prevent Bash parsing errors
declare -A ICON_FOR_CODE=(
  [0]="☀️" [1]="⛅️" [2]="⛅️" [3]="☁️"
  [45]="🌫" [48]="🌫"
  [51]="🌦️" [53]="🌧️" [55]="🌧️" [56]="🌧️" [57]="🌧️"
  [61]="🌧️" [63]="🌧️" [65]="🌧️" [66]="🌧️"[67]="🌧️"
  [71]="🌨️" [73]="🌨️" [75]="❄️" [77]="❄️"
  [80]="🌧️" [81]="🌧️" [82]="🌧️" [85]="🌨️" [86]="❄️"
  [95]="⛈" [96]="⛈" [99]="⛈" [113]="☀️" [116]="⛅️" [119]="☁️" [122]="☁️"
  [143]="🌫" [176]="🌦️" [179]="🌧️" [182]="🌧️" [185]="🌧️" [200]="⛈" [227]="🌨️" [230]="❄️"
  [248]="🌫" [260]="🌫" [263]="🌦️" [266]="🌧️"
  [281]="🌧️" [284]="🌧️" [293]="🌧️" [296]="🌧️" [299]="🌧️"
  [302]="🌧️" [305]="🌧️" [308]="🌧️" [311]="🌧️" [314]="🌧️"[317]="🌧️" [320]="🌨️" [323]="🌨️"[326]="🌨️" [329]="❄️"
  [332]="❄️" [335]="❄️" [338]="❄️" [350]="🌧️" [353]="🌦️"
  [356]="🌧️" [359]="🌧️" [362]="🌧️" [365]="🌧️" [368]="🌨️"
  [371]="❄️" [374]="🌧️" [377]="🌧️" [386]="⛈" [389]="🌩️" [392]="⛈" [395]="❄️"
)
icon_for_code(){ echo "${ICON_FOR_CODE[$1]:-✨}"; }

# --- 2) Wind direction → arrow ---
declare -A WIND_ARROW=(
  [N]="⬇️N" [NNE]="↙️NNE" [NE]="↙️NE" [ENE]="↙️ENE"
  [E]="⬅️E" [ESE]="↖️ESE" [SE]="↖️SE" [SSE]="↖️SSE"
  [S]="⬆️S" [SSW]="↗️SSW" [SW]="↗️SW" [WSW]="↗️WSW"
  [W]="➡️W" [WNW]="↘️WNW" [NW]="↘️NW" [NNW]="↘️NNW"
)
arrow_for_dir(){ echo "${WIND_ARROW[$1]:-}"; }

# Convert degrees to 16-point compass (Used by Open-Meteo)
degree_to_dir() {
  local val  
  val=$(awk "BEGIN {print int(($1/22.5)+0.5)}")
  local arr=(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)
  echo "${arr[$((val % 16))]}"
}

# --- 3) km/h → Beaufort ---
kmh_to_bft() {
  local kmh=$1
  if   (( kmh < 1 ));   then echo 0
  elif (( kmh <= 5 ));  then echo 1
  elif (( kmh <= 11 )); then echo 2
  elif (( kmh <= 19 )); then echo 3
  elif (( kmh <= 28 )); then echo 4
  elif (( kmh <= 38 )); then echo 5
  elif (( kmh <= 49 )); then echo 6
  elif (( kmh <= 61 )); then echo 7
  elif (( kmh <= 74 )); then echo 8
  elif (( kmh <= 88 )); then echo 9
  elif (( kmh <= 102 )); then echo 10
  elif (( kmh <= 117 )); then echo 11
  else echo 12
  fi
}

# --- 4) Open-Meteo Greek Translations ---
# Liberally spaced out
declare -A DESC_FOR_WMO=(
  [0]="Καθαρός" [1]="Κυρίως αίθριος" [2]="Μερικώς νεφελώδης" [3]="Συννεφιά"
  [45]="Ομίχλη" [48]="Ομίχλη πάχνης"
  [51]="Ελαφριά ψιχάλα" [53]="Μέτρια ψιχάλα" [55]="Πυκνή ψιχάλα"
  [56]="Παγωμένη ψιχάλα" [57]="Πυκνή παγωμένη ψιχάλα"
  [61]="Ασθενής βροχή" [63]="Μέτρια βροχή" [65]="Ισχυρή βροχή"
  [66]="Παγωμένη βροχή" [67]="Ισχυρή παγωμένη βροχή"
  [71]="Ασθενής χιονόπτωση" [73]="Μέτρια χιονόπτωση" [75]="Ισχυρή χιονόπτωση"
  [77]="Νιφάδες χιονιού" [80]="Ασθενής νεροποντή" [81]="Μέτρια νεροποντή" [82]="Ισχυρή νεροποντή"
  [85]="Ασθενείς χιονοπτώσεις" [86]="Ισχυρές χιονοπτώσεις"
  [95]="Καταιγίδα" [96]="Καταιγίδα με χαλάζι" [99]="Ισχυρή καταιγίδα"
)

# --- 5) Fetch Data based on Provider ---
if [[ "$WEATHER_PROVIDER" == "open-meteo" ]]; then
  
  # Calculate total days required by Open-Meteo API (Today + FORECAST_DAYS)
  TOTAL_DAYS=$((FORECAST_DAYS + 1))

  URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,sunrise,sunset,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant&timezone=Europe%2FAthens&forecast_days=${TOTAL_DAYS}"

  data=$(curl -s --connect-timeout 5 --max-time 10 "$URL")

  if [[ -z "$data" ]]; then
    if $TERMINAL_MODE; then
      # auto-switch provider
      echo "⚠️  API Error — switching provider from Open‑Meteo to wttr.in ..."
      echo "wttr" > "$PROVIDER_STATEFILE"
      exec "$0" --terminal
    else
      echo '{"text":"API Error"}'
      exit 0
    fi
  fi

  cur_code=$(jq -r '.current.weather_code // 0' <<<"$data")
  cur_temp=$(jq -r '.current.temperature_2m // 0' <<<"$data" | awk '{print int($1+0.5)}')
  cur_wind=$(jq -r '.current.wind_speed_10m // 0' <<<"$data" | awk '{print int($1+0.5)}')
  cur_dir_deg=$(jq -r '.current.wind_direction_10m // 0' <<<"$data")
  cur_dir=$(degree_to_dir "$cur_dir_deg")
  cur_desc="${DESC_FOR_WMO[$cur_code]:-Άγνωστο}"

  sunrise=$(jq -r '.daily.sunrise[0] // ""' <<<"$data" | cut -dT -f2)
  sunset=$(jq -r '.daily.sunset[0] // ""' <<<"$data" | cut -dT -f2)
  
  # Today's min, max, feels like, and rain probability
  cur_feels=$(jq -r '.current.apparent_temperature // 0' <<<"$data" | awk '{print int($1+0.5)}')
  today_min=$(jq -r '.daily.temperature_2m_min[0] // 0' <<<"$data" | awk '{print int($1+0.5)}')
  today_max=$(jq -r '.daily.temperature_2m_max[0] // 0' <<<"$data" | awk '{print int($1+0.5)}')
  today_rain=$(jq -r '.daily.precipitation_probability_max[0] // 0' <<<"$data")

  # Forecast mapped to Min/Max, Max Feeling, and Rain Probability
  FORECAST_LINES=$(
    jq -r --argjson limit "$TOTAL_DAYS" '
      range(1; $limit) as $i |
      "\(.daily.time[$i] // "")|\(.daily.weather_code[$i] // 0)|\(.daily.temperature_2m_min[$i] // 0)|\(.daily.temperature_2m_max[$i] // 0)|\(.daily.apparent_temperature_max[$i] // 0)|\(.daily.precipitation_probability_max[$i] // 0)|\(.daily.wind_speed_10m_max[$i] // 0)|\(.daily.wind_direction_10m_dominant[$i] // 0)"
    ' <<<"$data" \
    | while IFS="|" read -r day code tmin tmax tfeel rain w d_deg; do
        day_fmt=$(date -d "$day" '+%d-%m-%Y' 2>/dev/null || echo "$day")
        desc="${DESC_FOR_WMO[$code]:-Άγνωστο}"
        dir=$(degree_to_dir "${d_deg:-0}")

        # Safe rounding map
        tmin=$(echo "${tmin:-0}" | awk '{print int($1+0.5)}')
        tmax=$(echo "${tmax:-0}" | awk '{print int($1+0.5)}')
        tfeel=$(echo "${tfeel:-0}" | awk '{print int($1+0.5)}')
        rain=$(echo "${rain:-0}" | awk '{print int($1+0.5)}')
        w=$(echo "${w:-0}" | awk '{print int($1+0.5)}')

        if [[ "$mode" == "kmh" ]]; then wind_disp="${w} km/h"
        else wind_disp="$(kmh_to_bft "$w") Bft"; fi
        
        printf "%s: %s %s %s°-%s° (👤%s°C) ☔ %s%% %s %s\n" \
          "$day_fmt" "$desc" "$(icon_for_code "$code")" "$tmin" "$tmax" "$tfeel" "$rain" "$wind_disp" "$(arrow_for_dir "$dir")"
      done
  )

else

  # Wttr.in logic
  data=$(curl -s --connect-timeout 5 --max-time 10 'https://wttr.in/Χίος?format=j1&lang=el')
  if [[ -z "$data" || "$data" == *"Unknown location"* ]]; then
    if $TERMINAL_MODE; then
        echo "⚠️  API Error — switching provider from wttr.in to Open‑Meteo ..."
        echo "open-meteo" > "$PROVIDER_STATEFILE"
      exec "$0" --terminal
    else
      echo '{"text":"API Error"}'
      exit 0
    fi
  fi

  cur_code=$(jq -r '.current_condition[0].weatherCode'      <<<"$data")
  cur_temp=$(jq -r '.current_condition[0].temp_C'           <<<"$data")
  cur_wind=$(jq -r '.current_condition[0].windspeedKmph'    <<<"$data")
  cur_dir=$(jq -r '.current_condition[0].winddir16Point'    <<<"$data")
  cur_desc=$(jq -r '.current_condition[0].lang_el[0].value' <<<"$data")

  sunrise=$(jq -r '.weather[0].astronomy[0].sunrise' <<<"$data")
  sunset=$(jq -r '.weather[0].astronomy[0].sunset' <<<"$data")

  local_date=$(jq -r '.current_condition[0].localObsDateTime | split(" ")[0]' <<<"$data")
  
  # Today's feeling, min, max, and chance of rain
  cur_feels=$(jq -r '.current_condition[0].FeelsLikeC' <<<"$data")
  today_min=$(jq -r '.weather[0].mintempC' <<<"$data")
  today_max=$(jq -r '.weather[0].maxtempC' <<<"$data")
  today_rain=$(jq -r '[.weather[0].hourly[].chanceofrain | tonumber] | max' <<<"$data")

  # Forecast mapped to Min/Max, Midday Feeling, and Rain Probability
  FORECAST_LINES=$(
    jq -r '
      .weather[1:3][] |
      "\(.date)|\(.hourly[4].weatherCode)|\(.hourly[4].lang_el[0].value)|\(.mintempC)|\(.maxtempC)|\(.hourly[4].FeelsLikeC)|\([.hourly[].chanceofrain | tonumber] | max)|\(.hourly[4].windspeedKmph)|\(.hourly[4].winddir16Point)"
    ' <<<"$data" \
    | while IFS="|" read -r day code desc tmin tmax tfeel rain w d; do
        if [[ "$day" < "$local_date" ]]; then
          day=$(date -d "$day +1 day" '+%d-%m-%Y')
        else
          day=$(date -d "$day" '+%d-%m-%Y')
        fi

        if [[ "$mode" == "kmh" ]]; then wind_disp="${w} km/h"
        else wind_disp="$(kmh_to_bft "$w") Bft"; fi

        printf "%s: %s %s %s°-%s° (👤%s°C) ☔ %s%% %s %s\n" \
          "$day" "$desc" "$(icon_for_code "$code")" "$tmin" "$tmax" "$tfeel" "$rain" "$wind_disp" "$(arrow_for_dir "$d")"
      done
  )

fi

# --- 6) Build bar text ---
if [[ "$mode" == "kmh" ]]; then
  wind_display="${cur_wind} km/h"
else
  wind_display="$(kmh_to_bft "$cur_wind") Bft"
fi

text="$(icon_for_code "$cur_code") ${cur_temp}°C $wind_display $(arrow_for_dir "$cur_dir")"

# --- 7) Build tooltip ---
# Contains Min-Max, Feeling, and Rain probability for today ONLY.
tooltip=$(
  printf "🌅 %s - 🌇 %s | %s %s\n" \
    "$sunrise" \
    "$sunset" \
    "$(icon_for_code "$cur_code")" \
    "$cur_desc"
  
  printf "🌡️ %s°C-%s°C (Αίσθηση: %s°C) | ☔ %s%% | %s %s\n" \
    "$today_min" \
    "$today_max" \
    "$cur_feels" \
    "$today_rain" \
    "$wind_display" \
    "$(arrow_for_dir "$cur_dir")"

  echo ""  

  echo "$FORECAST_LINES"

  case "$WEATHER_PROVIDER" in
    wttr)        provider_label="wttr.in" ;;
    open-meteo)  provider_label="Open-Meteo" ;;
  esac
  
  echo "$provider_label"
)

if [[ -t 1 ]]; then
  echo "$tooltip"
  echo ""
  echo "🔧 Εντολές:"
  echo "  • Αλλαγή μονάδων ανέμου:   weather toggle && weather"
  echo "  • Αλλαγή παρόχου:          weather provider && weather"
  exit 0
fi

# --- 8) Emit JSON for Waybar ---
jq -nc --arg text "$text" --arg tooltip "$tooltip" \
  '{text: $text, tooltip: $tooltip}'

