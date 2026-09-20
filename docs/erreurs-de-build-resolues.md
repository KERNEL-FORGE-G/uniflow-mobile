# Build Errors Documentation

## Issues Resolved
1. **Theme API Mismatch**: `CardTheme` constructor used instead of `CardThemeData` in `lib/theme/app_theme.dart`.
2. **Plugin Compilation Errors**: Older versions of `workmanager`, `livekit_client`, `flutter_webrtc`, and `connectivity_plus` were incompatible with newer Flutter/Android build tools (specifically regarding removed `PluginRegistry.Registrar` API).

## Solutions
- Updated `lib/theme/app_theme.dart` to use `CardThemeData`.
- Updated `pubspec.yaml` to use compatible versions:
  - `workmanager: ^0.9.0+3`
  - `livekit_client: ^2.9.0`
  - `connectivity_plus: ^7.3.1`
- Generated release APK script in `scripts/build_apk.sh`.
