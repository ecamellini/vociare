#!/usr/bin/env bash
# Removes everything install.sh and the app created.
set -euo pipefail

APP=/Applications/Vociare.app
KEYCHAIN="$HOME/Library/Keychains/vociare-signing.keychain-db"

pkill -x Vociare || true
[[ -x "$APP/Contents/MacOS/Vociare" ]] && "$APP/Contents/MacOS/Vociare" --unregister-login-item
rm -rf "$APP"

if [[ -f "$KEYCHAIN" ]]; then
  keychains=()
  while IFS= read -r keychain; do
    [[ "$keychain" == "$KEYCHAIN" ]] || keychains+=("$keychain")
  done < <(security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"$//')
  security list-keychains -d user -s ${keychains[@]+"${keychains[@]}"}
  security delete-keychain "$KEYCHAIN"
fi
security delete-generic-password -s vociare-signing -a "$USER" >/dev/null 2>&1 || true

rm -rf "$HOME/Library/Caches/me.ecamel.vociare" "$HOME/Library/Caches/Vociare" \
  "$HOME/Library/HTTPStorages/me.ecamel.vociare" "$HOME/Library/HTTPStorages/Vociare"
# FluidAudio's shared model folder: other apps built on FluidAudio may use this model too.
rm -rf "$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml"
# Menu settings; the bare binary (`swift build` output) reads them under its executable name.
defaults delete me.ecamel.vociare >/dev/null 2>&1 || true
defaults delete Vociare >/dev/null 2>&1 || true
tccutil reset All me.ecamel.vociare >/dev/null 2>&1 || true
echo "Vociare removed"
