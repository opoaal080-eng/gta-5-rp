#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
INPUT="${1:-}"
if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo 'Usage: ./build_on_mac.sh /absolute/path/to/owned-game.zip-or-game.wasm'
  exit 2
fi
command -v xcodebuild >/dev/null || { echo "Requires macOS + Xcode"; exit 1; }
command -v rustup >/dev/null || { echo "Requires Rust"; exit 1; }
if [[ ! -d "$ROOT/muguet/.git" ]]; then
  git clone https://github.com/c22dev/muguet.git "$ROOT/muguet"
fi
cd "$ROOT/muguet"
git fetch origin 728c195ab02c746a1f2d626238bfe030b2f561fb
git checkout 728c195ab02c746a1f2d626238bfe030b2f561fb
python3 "$ROOT/apply_patch.py" "$ROOT/muguet"
FREE=1 BUNDLE_ID=fun.nightwell.gtarplab ./make-ios.sh "$INPUT" --ipa
echo "IPA: $ROOT/muguet/build/Muguet.ipa"
