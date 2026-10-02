# Local development toolchain

The Flutter version is pinned in `.tool_versions.yaml` (currently 3.47.4).
In this workspace, the persistent SDK lives at:

```sh
$HOME/.local/share/fluffychat-flutter-sdk
```

Use its `bin/flutter` and `bin/dart` directly if they are not on PATH. The old
`/tmp/fluffychat-flutter-sdk` location was temporary and may no longer exist.
Check these locations before downloading another SDK.

After changing English localization strings, run `flutter gen-l10n`. Generated
localization Dart files are ignored. Run `flutter analyze --no-pub` and focused
tests appropriate to behavioral changes. Use `flutter pub get` when restoring
the SDK or when package configuration still references its former location.

For Android, check the ignored `android/local.properties` and environment for
SDK paths. This workspace uses the AUR Android SDK at `/opt/android-sdk`.
Java 21 is needed for Android builds. Run Flutter/Gradle as the normal user.
Personal debug signing uses `$HOME/.android/debug.keystore`; never commit keys.
See `docs/automated-builds.md` for CI signing and device installation.
