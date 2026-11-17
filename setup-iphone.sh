#!/usr/bin/env bash
# Priprema Xcode projekta za instalaciju na sopstveni iPhone (besplatan Apple ID).
# Upotreba: ./setup-iphone.sh [TEAM_ID] [BUNDLE_ID]
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodebuild >/dev/null || { echo "Potreban je Xcode (Mac App Store)."; exit 1; }
if ! command -v xcodegen >/dev/null; then
  command -v brew >/dev/null || { echo "Instaliraj Homebrew: https://brew.sh"; exit 1; }
  brew install xcodegen
fi
LOCAL=Configs/Local.xcconfig
if [ -n "${1:-}" ] || [ ! -f "$LOCAL" ]; then
  TEAM="${1:-}"
  if [ -z "$TEAM" ]; then
    TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
      | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
  fi
  {
    echo "// Lokalna podesavanja (nije u git-u)"
    [ -n "$TEAM" ] && echo "DEVELOPMENT_TEAM = $TEAM"
    [ -n "${2:-}" ] && echo "PRODUCT_BUNDLE_IDENTIFIER = $2"
  } > "$LOCAL"
  echo "Upisano u $LOCAL: ${TEAM:-(Team ID nije pronađen – izaberi tim u Xcode-u)}"
fi
xcodegen generate
open ESLLink.xcodeproj
