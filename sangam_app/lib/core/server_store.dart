import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Where this install talks to.
///
/// The build-time `API_BASE_URL` is only a default. Whatever the reporter sets
/// in Settings wins and is remembered, so one APK can follow a server that
/// moves — a tunnel URL that changes on restart, a laptop on a new network, or
/// the real deployment later — without anyone rebuilding the app.
class ServerStore {
  static const _key = 'server_base_url';

  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.trim().isEmpty) return AppConfig.baseUrl;
    return saved.trim();
  }

  static Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalise(url));
  }

  /// Forget the override and fall back to the address baked in at build time.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Trims, drops any trailing slash, and assumes https:// when no scheme is
  /// given — typing "sangam.example.in" should not silently fail.
  static String normalise(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Null when the address looks usable, otherwise a sentence to show.
  static String? validate(String raw) {
    final url = normalise(raw);
    if (url.isEmpty) return 'Enter the server address';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      return 'That does not look like a web address';
    }
    return null;
  }
}
