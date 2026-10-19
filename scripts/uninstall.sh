#!/usr/bin/env bash
# Removes everything install.sh and the app created.
set -euo pipefail

KEYCHAIN="$HOME/Library/Keychains/parla-signing.keychain-db"

pkill -x Parla || true
rm -rf /Applications/Parla.app
if [[ -f "$KEYCHAIN" ]]; then
  # shellcheck disable=SC2046
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"' | grep -v parla-signing)
  security delete-keychain "$KEYCHAIN"
fi
rm -rf "$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml"
tccutil reset All me.ecamel.parla >/dev/null 2>&1 || true
echo "Parla removed"
