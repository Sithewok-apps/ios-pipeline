#!/bin/bash
# Signs an .ipa in place with an identity and a (wildcard) provisioning
# profile. Every app and app extension gets entitlements made for its own
# bundle ID (TEAMID.bundle.id), not the profile's wildcard "TEAMID.*", which
# iOS doesn't accept as an app's identity. Nested frameworks and dylibs are
# signed first, inside out.
#
#   sign-ipa.sh app.ipa "Apple Distribution: Name (TEAMID)" profile.mobileprovision keychain
set -euo pipefail
IPA=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
IDENTITY=$2
PROFILE=$3
KEYCHAIN=$4

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
security cms -D -i "$PROFILE" > "$WORK/profile.plist"
TEAM=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$WORK/profile.plist")

cd "$WORK"
unzip -q "$IPA" -d unpacked
cd unpacked

# Deepest bundles first, so an app is signed after the extensions inside it
find Payload \( -name '*.app' -o -name '*.appex' \) -type d | awk '{ print gsub("/", "/"), $0 }' | sort -rn | cut -d' ' -f2- |
while read -r bundle; do
  bid=$(plutil -extract CFBundleIdentifier raw -o - "$bundle/Info.plist")
  ent="$WORK/ent-$(echo "$bid" | tr -c 'A-Za-z0-9.' '_').plist"
  cat > "$ent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>$TEAM.$bid</string>
  <key>com.apple.developer.team-identifier</key><string>$TEAM</string>
  <key>get-task-allow</key><false/>
  <key>keychain-access-groups</key><array><string>$TEAM.$bid</string></array>
</dict></plist>
EOF
  cp "$PROFILE" "$bundle/embedded.mobileprovision"
  # Every framework and dylib in it, deepest first
  find "$bundle" \( -name '*.framework' -o -name '*.dylib' \) | awk '{ print gsub("/", "/"), $0 }' | sort -rn | cut -d' ' -f2- |
  while read -r item; do
    codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" "$item"
  done
  codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --entitlements "$ent" --generate-entitlement-der "$bundle"
  echo "Signed $bid"
done

codesign --verify --deep --strict Payload/*.app
rm -f "$IPA"
zip -qry "$IPA" .
