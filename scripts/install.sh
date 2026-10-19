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
# The signing keychain's random password lives in the login keychain under this service name.
PASSWORD_SERVICE=vociare-signing
tmp=""

cleanup() {
  [[ -n "$tmp" ]] && rm -rf "$tmp"
  # Whoever can unlock the signing keychain can sign as Vociare and inherit its permissions.
  [[ -f "$KEYCHAIN" ]] && security lock-keychain "$KEYCHAIN" 2>/dev/null
  return 0
}
trap cleanup EXIT

# The search list as one path per line, without the quotes and indentation `security` prints.
user_keychains() { security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"$//'; }

create_identity() {
  echo "First install: creating a self-signed signing identity in $KEYCHAIN, adding it to your keychain search list and storing its password in your login keychain."
  tmp=$(mktemp -d)
  local password keychains=()
  password=$(openssl rand -hex 24)
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$IDENTITY" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
  # macOS's `security import` only reads PKCS#12 files with the older encryption algorithms.
  openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/identity.p12" -passout "pass:$password" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
  security add-generic-password -U -s "$PASSWORD_SERVICE" -a "$USER" -w "$password"
  security create-keychain -p "$password" "$KEYCHAIN"
  security set-keychain-settings -l -u -t 300 "$KEYCHAIN"
  # -x keeps the private key from ever being exported.
  security import "$tmp/identity.p12" -k "$KEYCHAIN" -P "$password" -x -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$KEYCHAIN" >/dev/null
  # codesign only finds identities in keychains on the search list, even when given --keychain.
  while IFS= read -r keychain; do keychains+=("$keychain"); done < <(user_keychains)
  security list-keychains -d user -s ${keychains[@]+"${keychains[@]}"} "$KEYCHAIN"
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
security unlock-keychain -p "$(security find-generic-password -s "$PASSWORD_SERVICE" -a "$USER" -w)" "$KEYCHAIN"
codesign --force --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP"
security lock-keychain "$KEYCHAIN"

# Run from inside the bundle: Core ML caches the compiled model per bundle ID, and the app reads only its own.
"$APP/Contents/MacOS/Vociare" --download-model || echo "Model download failed; Vociare will retry on the first dictation."

pkill -x Vociare || true
# Launching while the old instance is still quitting fails with LaunchServices error -600.
while pgrep -x Vociare >/dev/null; do sleep 0.2; done
rm -rf "$INSTALL_DIR/Vociare.app"
cp -R "$APP" "$INSTALL_DIR/"
open "$INSTALL_DIR/Vociare.app"
echo "Installed $INSTALL_DIR/Vociare.app"
