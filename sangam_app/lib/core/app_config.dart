import 'dart:io';

/// Where the API lives.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
///
/// The default is host-aware because an Android emulator cannot reach the
/// host's 127.0.0.1 — it sees the host as 10.0.2.2.
class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://127.0.0.1:4000';
  }

  static const appName = 'SANGAM';
  static const maxPhotos = 5;
}
