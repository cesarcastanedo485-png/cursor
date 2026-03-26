# Release checklist (v1 “finished”)

## Beta vs v1

- **Label now:** **Beta** — core flows exist; ship as v1 only after every item below is done and you’ve device-tested install + Cloud Agents + one Private AI + one Capability you rely on.
- **Alpha** would mean broken/incomplete core flows; that’s not the target for this repo.
- **Cursor ToS / store:** see `DISTRIBUTION_AND_CURSOR_TOS.md` and publish a privacy policy from `PRIVACY_POLICY_TEMPLATE.md`.

## Machine

- [ ] Enough **free disk** for `flutter pub get` and `flutter build apk` / `appbundle` (clean `build/` if needed: `flutter clean`).
- [ ] `flutter doctor` clean for your target platforms.

## Quality gate

- [ ] `flutter analyze` — no issues
- [ ] `flutter test` — all green
- [ ] **APK log:** append a new top entry in `lib/core/apk_release_log.dart` matching the new `pubspec.yaml` `version:` (so Settings → About stays accurate)
- [ ] **What's New:** Verify What's New modal shows correctly for the new version (upgrade from previous build)
- [ ] Optional: `.\scripts\pre_push.ps1` (same as above)

## Signing & secrets

- [ ] `android/key.properties` present locally (from `key.properties.example`), **strong** passwords — see `docs/SECRETS.md`
- [ ] `upload-keystore.jks` backed up offline
- [ ] No secrets in git (`git status`, scan for accidental commits)

## Build

- [ ] `flutter build apk --release` and/or `flutter build appbundle --release`
- [ ] Smoke-test install on a physical device

## Updates

- [ ] If side-loading: verify **Check for updates** URL on device — see `docs/UPDATES.md`
- [ ] If Play: internal testing track first

## Store / legal

- [ ] Privacy policy URL live — start from `docs/PRIVACY_POLICY_TEMPLATE.md`
- [ ] Review `docs/DISTRIBUTION_AND_CURSOR_TOS.md` for your distribution model

## Version

- [ ] Bump `version:` in `pubspec.yaml` and changelog/release notes
