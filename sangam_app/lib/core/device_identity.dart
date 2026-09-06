import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The device UUID that stands in for an account.
///
/// This is a bookmark, not a credential. It answers exactly one question —
/// "whose reports show under My reports?" — and it is never treated as proof
/// of who the reporter is. Reinstalling the app mints a new one, which is why
/// every report also carries a public ID anyone can look up.
class DeviceIdentity {
  static const _key = 'device_id';

  /// Pins the device to a known UUID for demos and manual testing:
  ///   flutter run --dart-define=DEVICE_ID=00000000-0000-4000-8000-000000000001
  /// Without it the app mints its own on first launch, which is the real
  /// behaviour on a phone.
  static const _override = String.fromEnvironment('DEVICE_ID');

  static Future<String> ensure() async {
    final prefs = await SharedPreferences.getInstance();
    if (_override.isNotEmpty) {
      await prefs.setString(_key, _override);
      return _override;
    }
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    return id;
  }

  static String get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'android';
  }
}
