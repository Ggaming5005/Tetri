# Tetri mobile

Flutter 3.47.9 / Dart 3.13.7. This folder contains Tetri's design system and debug component gallery; see the root README for phase status and backend setup.

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter run --dart-define=TETRI_GALLERY=true
```

The gallery is debug-only. Long-press the wordmark or use the define above to open it. All text, geometry, colors, typography and motion use shared tokens; money stays in integer minor units. Inter and the original illustration are bundled for offline use.
