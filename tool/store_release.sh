#!/usr/bin/env bash
# Build store artifacts: iOS IPA (App Store Connect export) + Android App Bundle.
#
# iOS: Signing uses Xcode automatic signing + your login keychain (Apple ID / certs).
#      Run: open ios/Runner.xcworkspace once and ensure Signing & Capabilities is green.
#
# Android: Copy android/key.properties.example → android/key.properties and set paths/passwords,
#          or export ANDROID_KEYSTORE_PATH, ANDROID_STORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD.
#          Optional: pull a password from Keychain, e.g.
#          export ANDROID_STORE_PASSWORD="$(security find-generic-password -s 'note-to-self-android-store' -w)"
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> iOS: build IPA (App Store Connect export)"
IPA_OK=0
if ! flutter build ipa --export-options-plist="$ROOT/ios/ExportOptions-appstore.plist"; then
  IPA_OK=1
fi
if [[ "$IPA_OK" -ne 0 ]] || ! ls "$ROOT/build/ios/ipa/"*.ipa >/dev/null 2>&1; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "iOS export failed (archive may still exist — see below)."
  echo ""
  echo "Your error usually means Apple does not yet have an App ID + distribution"
  echo "profile for: online.nextelevenstudios.notetoself"
  echo ""
  echo "Do this once (paid Apple Developer Program, Account Holder or Admin):"
  echo "  1) https://developer.apple.com/account/resources/identifiers/list"
  echo "     → + → App IDs → App → register online.nextelevenstudios.notetoself"
  echo "  2) https://appstoreconnect.apple.com → My Apps → + → New App"
  echo "     → same bundle ID, same team as Xcode (L35VLYNTLK)"
  echo "  3) Xcode → Settings → Accounts → your Apple ID → Download Manual Profiles"
  echo "     (or open ios/Runner.xcworkspace → Signing & Capabilities → Automatic)"
  echo "  4) Re-run: ./tool/store_release.sh"
  echo ""
  echo "Or distribute the existing archive in Xcode (often clearer errors):"
  echo "  open \"$ROOT/build/ios/archive/Runner.xcarchive\""
  echo ""
  echo "App Store also requires real app icons (not Flutter defaults) — replace"
  echo "ios/Runner/Assets.xcassets/AppIcon.appiconset before submission."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

if [[ ! -f "$ROOT/android/key.properties" ]] && [[ -z "${ANDROID_KEYSTORE_PATH:-}" ]]; then
  echo "Android: No android/key.properties and no ANDROID_KEYSTORE_PATH."
  echo "Play Store needs a release-signed AAB. Create android/key.properties from key.properties.example"
  echo "or set the ANDROID_* env vars, then re-run this script."
  echo ""
else
  echo "==> Android: build App Bundle"
  flutter build appbundle
fi

echo ""
echo "Done."
if ls "$ROOT/build/ios/ipa/"*.ipa >/dev/null 2>&1; then
  echo "  iOS IPA:    $ROOT/build/ios/ipa/"
else
  echo "  iOS IPA:    (not created — see messages above)"
fi
echo "  Android:    $ROOT/build/app/outputs/bundle/release/app-release.aab (if built)"
echo ""
echo "Upload:"
echo "  • App Store: Transporter app, or: cd fastlane && bundle exec fastlane ios upload_ipa"
echo "  • Play: Play Console → Testing/Production → Create release, or: bundle exec fastlane android upload_aab"
