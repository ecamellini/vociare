#!/usr/bin/env bash
# Builds Vociare.app, signs it and installs it into /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."
APP=build/Vociare.app
INSTALL_DIR=/Applications
IDENTITY="Vociare Self-Signed"
# macOS ties Microphone and Accessibility grants to the signing certificate. Ad-hoc signatures change on
# every build and would make you grant both again; a stable self-signed certificate keeps them.
KEYCHAIN="$HOME/Library/Keychains/vociare-signing.keychain-db"
# Only guards a throwaway self-signed key, kept in its own keychain so signing never prompts.
KEYCHAIN_PASSWORD=vociare

create_identity() {
  echo "First install: creating a self-signed signing identity in $KEYCHAIN and adding it to your keychain search list."
  local tmp
  tmp=$(mktemp -d)
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$IDENTITY" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
  # macOS's `security import` only reads PKCS#12 files with the older encryption algorithms.
  openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/identity.p12" -passout pass:vociare \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings "$KEYCHAIN"
  security import "$tmp/identity.p12" -k "$KEYCHAIN" -P vociare -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
  # codesign only finds identities in keychains on the search list, even when given --keychain.
  # shellcheck disable=SC2046
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KEYCHAIN"
  rm -rf "$tmp"
}

# The Swift Build backend fails to start with only the Command Line Tools installed.
swift build -c release --build-system native

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Vociare "$APP/Contents/MacOS/Vociare"
rm -rf build/AppIcon.iconset
.build/release/Vociare --render-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"

[[ -f "$KEYCHAIN" ]] || create_identity
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
codesign --force --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP"

.build/release/Vociare --download-model || echo "Model download failed; Vociare will retry on the first dictation."

pkill -x Vociare || true
# Launching while the old instance is still quitting fails with LaunchServices error -600.
while pgrep -x Vociare >/dev/null; do sleep 0.2; done
rm -rf "$INSTALL_DIR/Vociare.app"
cp -R "$APP" "$INSTALL_DIR/"
open "$INSTALL_DIR/Vociare.app"
echo "Installed $INSTALL_DIR/Vociare.app"
