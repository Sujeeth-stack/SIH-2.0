import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Optional reporter details, remembered on the device so the form pre-fills
/// next time. Nothing here is verified and nothing here grants any privilege.
class ReporterStore {
  static const _name = 'reporter_name';
  static const _phone = 'reporter_phone';
  static const _type = 'reporter_type';
  static const _org = 'reporter_org';
  static const _lang = 'language';

  static Future<ReporterProfile> load() async {
    final p = await SharedPreferences.getInstance();
    return ReporterProfile(
      name: p.getString(_name),
      phone: p.getString(_phone),
      type: p.getString(_type) ?? 'CITIZEN',
      org: p.getString(_org),
    );
  }

  static Future<void> save(ReporterProfile v) async {
    final p = await SharedPreferences.getInstance();
    Future<void> put(String k, String? s) async {
      if (s == null || s.trim().isEmpty) {
        await p.remove(k);
      } else {
        await p.setString(k, s.trim());
      }
    }

    await put(_name, v.name);
    await put(_phone, v.phone);
    await put(_org, v.org);
    await p.setString(_type, v.type);
  }

  static Future<String> language() async =>
      (await SharedPreferences.getInstance()).getString(_lang) ?? 'en';

  static Future<void> setLanguage(String code) async =>
      (await SharedPreferences.getInstance()).setString(_lang, code);
}
