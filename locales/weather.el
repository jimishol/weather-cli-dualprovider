#!/usr/bin/env bash
# locales/weather.el.sh
# Greek locale for weather-cli-dualprovider
# LOCALE_VERSION helps detect incompatible changes
LOCALE_VERSION="1"

# WMO code → Greek description
declare -A DESC_FOR_WMO=(
  [0]="Αίθριος"
  [1]="Κυρίως αίθριος"
  [2]="Μερικώς νεφελώδης"
  [3]="Συννεφιά"
  [45]="Ομίχλη"
  [48]="Ομίχλη πάχνης"
  [51]="Ελαφριά ψιχάλα"
  [53]="Μέτρια ψιχάλα"
  [55]="Πυκνή ψιχάλα"
  [56]="Ελαφριά παγωμένη ψιχάλα"
  [57]="Πυκνή παγωμένη ψιχάλα"
  [61]="Ασθενής βροχή"
  [63]="Μέτρια βροχή"
  [65]="Ισχυρή βροχή"
  [66]="Ελαφριά παγωμένη βροχή"
  [67]="Ισχυρή παγωμένη βροχή"
  [71]="Ασθενής χιονόπτωση"
  [73]="Μέτρια χιονόπτωση"
  [75]="Ισχυρή χιονόπτωση"
  [77]="Χιονοκόκκοι"
  [80]="Ασθενείς μπόρες"
  [81]="Μέτριες μπόρες"
  [82]="Ισχυρές μπόρες"
  [85]="Ασθενείς χιονομπόρες"
  [86]="Ισχυρές χιονομπόρες"
  [95]="Ασθενής έως μέτρια καταιγίδα"
  [96]="Καταιγίδα με μικρό χαλάζι"
  [99]="Καταιγίδα με μεγάλο χαλάζι"
)

# Localized static labels used in tooltip and messages
LABEL_SUNRISE="Ανατολή"
LABEL_SUNSET="Δύση"
LABEL_FEELS="Αίσθηση"
LABEL_RAIN="Βροχή"
LABEL_PROVIDER_WTTR="wttr.in"
LABEL_PROVIDER_OPENMETEO="Open‑Meteo"
LABEL_UNKNOWN="Άγνωστο"
