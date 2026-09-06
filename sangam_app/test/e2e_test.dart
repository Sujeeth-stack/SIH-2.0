import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangam/data/api.dart';
import 'package:uuid/uuid.dart';

/// Drives the real app against a running sangam-api and Postgres.
///
///   node src/server.js   # in sangam_api
///   flutter test test/e2e_test.dart
///
/// Skipped automatically when the API is not up, so `flutter test` stays green
/// on a machine with no backend.
const _baseUrl = 'http://127.0.0.1:4000';

Future<bool> _apiUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final req = await client.getUrl(Uri.parse('$_baseUrl/health'));
    final res = await req.close();
    client.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  late bool up;
  late SangamApi api;
  final deviceId = const Uuid().v4();

  setUpAll(() async {
    // flutter_test stubs out networking by default; restore it so these tests
    // talk to the real server.
    HttpOverrides.global = null;
    up = await _apiUp();
    api = SangamApi(deviceId: deviceId, baseUrl: _baseUrl);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a submitted report is persisted and comes back by public ID', () async {
    if (!up) return;
    await api.registerDevice(language: 'en');

    final problemId = const Uuid().v4();
    final created = await api.submitProblem(
      problemId: problemId,
      title: 'Culvert collapsed on the school road',
      description: 'Children are wading through the drain to reach school.',
      domain: 'ROADS',
      latitude: 23.3441,
      longitude: 85.3096, // Ranchi
      peopleAffected: 320,
      durationLabel: 'ONE_TO_FOUR_WEEKS',
      consent: true,
    );

    // The server resolved the district from the coordinates and minted an ID.
    expect(created.publicRef, startsWith('JH-RAN-'));
    expect(created.districtCode, 'RAN');
    expect(created.status, 'SUBMITTED');

    // Re-posting the same problem_id must not create a second row.
    final again = await api.submitProblem(
      problemId: problemId,
      title: 'Culvert collapsed on the school road',
      description: '',
      domain: 'ROADS',
    );
    expect(again.problemId, created.problemId);
    expect(again.publicRef, created.publicRef);

    // It is readable by anyone holding the printed ID.
    final looked = await api.problemByRef(created.publicRef);
    expect(looked.problem.title, created.title);
    expect(looked.history, isNotEmpty);
    expect(looked.history.first.status, 'SUBMITTED');

    // And it is the only report this device has sent.
    final mine = await api.myReports();
    expect(mine.length, 1);
    expect(mine.first.problemId, problemId);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an unknown report ID is reported, not crashed on', () async {
    if (!up) return;
    expect(
      () => api.problemByRef('JH-XXX-999999'),
      throwsA(isA<ApiException>()),
    );
  });
}
