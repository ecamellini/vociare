#!/usr/bin/env bash
# Removes everything install.sh and the app created.
set -euo pipefail

KEYCHAIN="$HOME/Library/Keychains/vociare-signing.keychain-db"

pkill -x Vociare || true
rm -rf /Applications/Vociare.app
if [[ -f "$KEYCHAIN" ]]; then
  # shellcheck disable=SC2046
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"' | grep -v vociare-signing)
  security delete-keychain "$KEYCHAIN"
fi
rm -rf "$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml"
tccutil reset All me.ecamel.vociare >/dev/null 2>&1 || true
echo "Vociare removed"
