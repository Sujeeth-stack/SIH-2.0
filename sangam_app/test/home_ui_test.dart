import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangam/core/theme.dart';
import 'package:sangam/data/api.dart';
import 'package:sangam/features/home/home_shell.dart';

/// Serves canned JSON so the UI can be driven under a `testWidgets` fake
/// clock, which would never let real network I/O complete.
class _StubAdapter implements HttpClientAdapter {
  final Map<String, Object?> routes;
  _StubAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _,
      Future<void>? __) async {
    final match = routes.keys.firstWhere(
      (k) => options.path.startsWith(k),
      orElse: () => '',
    );
    if (match.isEmpty) {
      return ResponseBody.fromString('{"error":{"message":"no stub"}}', 404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    return ResponseBody.fromString(jsonEncode(routes[match]), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _problem(String title, String status, String ref) => {
      'problem_id': '11111111-1111-4111-8111-111111111111',
      'public_ref': ref,
      'title': title,
      'description': '',
      'domain': 'ELECTRICITY',
      'status': status,
      'district_code': 'DHN',
      'district_name': 'Dhanbad',
      'location_label': 'Dhanbad, Jharkhand',
      'reporter_type': 'CITIZEN',
      'official_source': false,
      'media_count': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHome(WidgetTester tester, SangamApi api) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: HomeShell(api: api)),
    );
    // Spinners animate forever, so pumpAndSettle would never return.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('first frame is the main page — there is no login anywhere',
      (tester) async {
    final api = SangamApi(
      deviceId: '22222222-2222-4222-8222-222222222222',
      adapter: _StubAdapter({
        '/problems': {
          'problems': [
            _problem('Street light out near the bus stand', 'SUBMITTED',
                'JH-DHN-000012'),
          ],
        },
        '/devices': {'device': {}},
      }),
    );

    await pumpHome(tester, api);

    expect(find.text('SANGAM'), findsOneWidget);
    expect(find.text('Report a problem'), findsWidgets);

    // Nothing that smells like an auth wall.
    expect(find.textContaining('Login'), findsNothing);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);
    expect(find.textContaining('Password'), findsNothing);

    // The three tabs from the spec.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My reports'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('recent reports render with their ID and status', (tester) async {
    final api = SangamApi(
      deviceId: '22222222-2222-4222-8222-222222222222',
      adapter: _StubAdapter({
        '/problems': {
          'problems': [
            _problem('Street light out near the bus stand', 'IN_EXECUTION',
                'JH-DHN-000012'),
          ],
        },
      }),
    );

    await pumpHome(tester, api);

    expect(find.text('Street light out near the bus stand'), findsOneWidget);
    expect(find.text('JH-DHN-000012'), findsOneWidget);
    // Twice on purpose: the card's status chip, and the stat-row label that
    // this report is now counted under.
    expect(find.text('In progress'), findsNWidgets(2));
    // The stat row still labels the submitted and resolved columns.
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
  });

  testWidgets('an empty device sees the empty state, not a blank screen',
      (tester) async {
    final api = SangamApi(
      deviceId: '22222222-2222-4222-8222-222222222222',
      adapter: _StubAdapter({'/problems': {'problems': []}}),
    );

    await pumpHome(tester, api);

    expect(find.text('Nothing reported from this phone yet.'), findsOneWidget);
  });

  testWidgets('an unreachable server shows a banner, it does not block the app',
      (tester) async {
    final api = SangamApi(
      deviceId: '22222222-2222-4222-8222-222222222222',
      adapter: _StubAdapter(const {}), // every route 404s
    );

    await pumpHome(tester, api);

    expect(find.text('Report a problem'), findsWidgets);
    expect(find.textContaining('Cannot reach the server'), findsOneWidget);
  });
}
