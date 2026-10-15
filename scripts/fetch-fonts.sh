#!/usr/bin/env bash
# Downloads the two bundled fonts (OFL) from the google/fonts repository into app_flutter/assets/fonts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/app_flutter/assets/fonts"; mkdir -p "$D"
B="https://raw.githubusercontent.com/google/fonts/main/ofl"
for w in Regular Medium SemiBold Bold; do curl -sSL -o "$D/BeVietnamPro-$w.ttf" "$B/bevietnampro/BeVietnamPro-$w.ttf"; done
curl -sSL -o "$D/Fraunces-Variable.ttf" "$B/fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
curl -sSL -o "$D/OFL.txt" "$B/bevietnampro/OFL.txt"
ls -la "$D"
