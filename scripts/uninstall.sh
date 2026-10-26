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
tccutil reset All me.ecamel.vociare >/dev/null 2>&1 || true
echo "Vociare removed"

# Other apps built on FluidAudio share this folder, and there's no way to tell whether one still uses it.
MODEL="$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml"
if [[ -d "$MODEL" ]]; then
  answer=n
  if [[ -t 0 ]]; then
    read -r -p "Also delete the speech model, which other FluidAudio apps may use? [y/N] " answer || true
  fi
  if [[ "$answer" == [yY]* ]]; then
    rm -rf "$MODEL"
    echo "Model deleted"
  else
    echo "Model kept in $MODEL"
  fi
fi
