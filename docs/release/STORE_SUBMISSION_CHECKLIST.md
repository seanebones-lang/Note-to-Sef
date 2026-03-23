# Store Submission Checklist

Use this checklist for production submissions to Apple and Google.

## Identity and Versioning

- [ ] Confirm app IDs:
  - [ ] iOS/macOS bundle ID: `online.nextelevenstudios.notetoself`
  - [ ] Android application ID: `online.nextelevenstudios.notetoself`
- [ ] Bump app version and build number in `pubspec.yaml`.
- [ ] Verify release notes/changelog.

## Legal and Policy

- [ ] Publish Privacy Policy URL for store listing:
  - [ ] `https://seanebones-lang.github.io/Note-to-Sef/privacy-policy.html`
- [ ] Publish EULA / Terms URL if required by your release process:
  - [ ] `https://seanebones-lang.github.io/Note-to-Sef/eula.html`
- [ ] Confirm support URL in listing:
  - [ ] `https://seanebones-lang.github.io/Note-to-Sef/support-policy.html`
- [ ] Keep legal docs landing page available:
  - [ ] `https://seanebones-lang.github.io/Note-to-Sef/`
- [ ] Ensure Data Safety (Google Play) and Privacy Nutrition (Apple) answers match actual app behavior.

## App Assets

- [ ] Replace default app icons for all required sizes.
- [ ] Prepare store screenshots for required devices.
- [ ] Verify app name, subtitle/short description, long description.

## iOS / TestFlight / App Store

- [ ] Archive and build IPA:
  - [ ] `flutter build ipa --export-options-plist=ios/ExportOptions-appstore.plist`
- [ ] Upload IPA via Transporter or fastlane.
- [ ] Wait for processing in App Store Connect.
- [ ] Complete compliance forms (export compliance, age rating, etc.).
- [ ] Assign build to TestFlight testers.

## Android / Play Console

- [ ] Ensure `android/key.properties` points to release keystore.
- [ ] Build release AAB:
  - [ ] `flutter build appbundle`
- [ ] Upload `build/app/outputs/bundle/release/app-release.aab`.
- [ ] Complete Play Console testing and policy declarations.
- [ ] Roll out to internal/closed track before production.

## Desktop Distribution (if applicable)

- [ ] Build macOS release:
  - [ ] `flutter build macos --release`
- [ ] Package `.app` as zip for distribution.
- [ ] If distributing publicly, sign/notarize according to Apple requirements.

