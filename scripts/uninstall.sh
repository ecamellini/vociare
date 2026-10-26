#!/usr/bin/env bash
# Removes everything install.sh and the app created, except the shared speech model, which it offers to delete.
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
# Menu settings; the bare binary (`swift build` output) reads them under its executable name.
defaults delete me.ecamel.vociare >/dev/null 2>&1 || true
defaults delete Vociare >/dev/null 2>&1 || true
tccutil reset All me.ecamel.vociare >/dev/null 2>&1 || true
echo "Vociare removed"

# Other apps built on FluidAudio share these folders, and there's no way to tell whether one still uses them.
# The -coreml folder is where FluidAudio 0.9.1, used by earlier Vociare versions, kept the model.
MODELS="$HOME/Library/Application Support/FluidAudio/Models"
models=()
for model in "$MODELS/parakeet-tdt-0.6b-v3" "$MODELS/parakeet-tdt-0.6b-v3-coreml"; do
  [[ -d "$model" ]] && models+=("$model")
done
if (( ${#models[@]} )); then
  answer=n
  if [[ -t 0 ]]; then
    read -r -p "Also delete the speech model, which other FluidAudio apps may use? [y/N] " answer || echo
  fi
  if [[ "$answer" == [yY]* ]]; then
    rm -rf "${models[@]}"
    echo "Model deleted"
  else
    printf 'Model kept in %s\n' "${models[@]}"
  fi
fi
