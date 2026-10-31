#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ASSETS="ios-launcher/Sources/Assets.xcassets"
mkdir -p "$ASSETS/AppIcon.appiconset" "$ASSETS/GTA5RPLogo.imageset"
# Design reference: https://mmoguider.ru/cms/uploads/gta5rp_76c9442556.jpg?f=jpg
# Optional third-party asset; a matching original fallback is drawn if unavailable.
curl -fLsS --retry 2 --connect-timeout 7 --max-time 18 \
 "https://mmoguider.ru/cms/uploads/gta5rp_76c9442556.jpg?f=jpg" \
 -o /tmp/gta5rp-official-reference.jpg || true
swift ios-launcher/make-brand.swift "$ASSETS" "/tmp/gta5rp-official-reference.jpg"
