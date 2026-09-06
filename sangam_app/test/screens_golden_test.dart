import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangam/core/theme.dart';
import 'package:sangam/data/api.dart';
import 'package:sangam/features/dashboard/dashboard_page.dart';
import 'package:sangam/features/home/home_shell.dart';
import 'package:sangam/features/lookup/public_lookup_page.dart';
import 'package:sangam/features/report/report_flow_page.dart';
import 'package:sangam/features/settings/settings_page.dart';
import 'package:sangam/features/track/my_reports_page.dart';
import 'package:sangam/features/track/report_detail_page.dart';

/// Renders every screen at phone size and writes a PNG, so the UI can be
/// reviewed without a device. Run with:
///   flutter test test/screens_golden_test.dart --update-goldens
///
/// The real fonts are bundled assets, so the goldens show actual type rather
/// than the test framework's placeholder boxes.
const _phone = Size(390, 844);

Future<void> _loadFonts() async {
  // MaterialIcons ships with the SDK; without it every icon is an empty box.
  // Walk up from the Dart binary to find the Flutter cache, so this keeps
  // working wherever the SDK is installed.
  File? iconFont;
  for (var dir = File(Platform.resolvedExecutable).parent;
      dir.path != dir.parent.path;
      dir = dir.parent) {
    final candidate = File(
        '${dir.path}/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (candidate.existsSync()) {
      iconFont = candidate;
      break;
    }
  }
  final fonts = {
    'Inter': 'assets/fonts/Inter.ttf',
    'NotoSansDevanagari': 'assets/fonts/NotoSansDevanagari.ttf',
    if (iconFont != null) 'MaterialIcons': iconFont.path,
  };
  for (final entry in fonts.entries) {
    final bytes = File(entry.value).readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// Canned API responses so the screens render with realistic content.
class _DemoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    Object? body;
    final p = o.path;

    if (p.startsWith('/analytics/summary')) {
      body = _analytics;
    } else if (p.startsWith('/reference/domains')) {
      body = {'domains': _domains};
    } else if (p.startsWith('/reference/districts')) {
      body = {
        'districts': [
          {'code': 'DMK', 'name': 'Dumka'},
          {'code': 'RAN', 'name': 'Ranchi'},
        ]
      };
    } else if (p.contains('/problems/') && !p.startsWith('/problems?')) {
      body = _detail;
    } else if (p.startsWith('/problems')) {
      body = {'problems': _reports};
    } else {
      body = {'device': {}};
    }

    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _report(
        String id, String ref, String title, String status, String district) =>
    {
      'problem_id': id,
      'public_ref': ref,
      'title': title,
      'description':
          'The only handpump in the tola has run dry. Women walk 2 km for water.',
      'domain': 'WATER',
      'status': status,
      'district_code': district.substring(0, 3).toUpperCase(),
      'district_name': district,
      'location_label': '$district, Jharkhand',
      'latitude': 24.2676,
      'longitude': 87.2497,
      'people_affected': 180,
      'duration_label': 'MORE_THAN_MONTH',
      'reporter_type': 'CITIZEN',
      'official_source': false,
      'media_count': 2,
      'created_at':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

final _reports = [
  _report('11111111-1111-4111-8111-111111111111', 'JH-DMK-000417',
      'Handpump dry for three weeks', 'IN_EXECUTION', 'Dumka'),
  _report('22222222-2222-4222-8222-222222222222', 'JH-RAN-000118',
      'School toilet blocked since the rains', 'VALIDATED', 'Ranchi'),
  _report('33333333-3333-4333-8333-333333333333', 'JH-DHN-000052',
      'Street light out near the bus stand', 'CLOSED_WITH_IMPACT', 'Dhanbad'),
  _report('44444444-4444-4444-8444-444444444444', 'JH-HAZ-000090',
      'Culvert washed away on the school road', 'ROUTED', 'Hazaribagh'),
];

final _detail = {
  'problem': _reports.first,
  'media': const [],
  'history': [
    {
      'id': 1,
      'status': 'SUBMITTED',
      'note': 'Report submitted from the SANGAM app.',
      'actor': 'citizen',
      'created_at':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'id': 2,
      'status': 'VALIDATED',
      'note': 'Verified by the block office. Tanker arranged while the '
          'borewell is deepened.',
      'actor': 'officer:BDO Dumka',
      'created_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'id': 3,
      'status': 'IN_EXECUTION',
      'note': 'Rig scheduled for Thursday.',
      'actor': 'officer:JE PHED',
      'created_at': DateTime.now().toIso8601String(),
    },
  ],
};

const _domains = [
  {'code': 'WATER', 'label': 'Water supply'},
  {'code': 'SANITATION', 'label': 'Sanitation'},
  {'code': 'ROADS', 'label': 'Roads & transport'},
  {'code': 'ELECTRICITY', 'label': 'Electricity'},
  {'code': 'HEALTH', 'label': 'Health'},
  {'code': 'EDUCATION', 'label': 'Education'},
  {'code': 'AGRICULTURE', 'label': 'Agriculture'},
  {'code': 'LIVELIHOOD', 'label': 'Livelihood'},
  {'code': 'ENVIRONMENT', 'label': 'Environment'},
  {'code': 'CONNECTIVITY', 'label': 'Phone & internet'},
  {'code': 'OTHER', 'label': 'Something else'},
];

const _analytics = {
  'totals': {'total': 7, 'open': 5, 'resolved': 1},
  'by_status': [
    {'status': 'SUBMITTED', 'count': 2},
    {'status': 'IN_EXECUTION', 'count': 2},
    {'status': 'VALIDATED', 'count': 1},
    {'status': 'CLOSED_WITH_IMPACT', 'count': 1},
    {'status': 'REJECTED', 'count': 1},
  ],
  'by_district': [
    {'code': 'DMK', 'name': 'Dumka', 'count': 3},
    {'code': 'RAN', 'name': 'Ranchi', 'count': 2},
    {'code': 'DHN', 'name': 'Dhanbad', 'count': 1},
    {'code': 'HAZ', 'name': 'Hazaribagh', 'count': 1},
  ],
  'by_domain': [
    {'domain': 'WATER', 'count': 3},
    {'domain': 'SANITATION', 'count': 2},
    {'domain': 'ROADS', 'count': 1},
    {'domain': 'ELECTRICITY', 'count': 1},
  ],
};

void main() {
  late SangamApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = SangamApi(
      deviceId: '00000000-0000-4000-8000-000000000001',
      adapter: _DemoAdapter(),
    );
  });

  Future<void> shoot(WidgetTester tester, Widget screen, String name) async {
    tester.view.physicalSize = _phone * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: screen,
    ));
    // Spinners never settle, so pump a bounded number of frames instead.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/$name.png'),
    );
  }

  testWidgets('home', (t) => shoot(t, HomeShell(api: api), '01_home'));

  testWidgets('report step 1',
      (t) => shoot(t, ReportFlowPage(api: api), '02_report_step1'));

  testWidgets('my reports',
      (t) => shoot(t, MyReportsPage(api: api), '03_my_reports'));

  testWidgets(
      'report detail',
      (t) => shoot(
          t,
          ReportDetailPage(
              api: api, problemId: '11111111-1111-4111-8111-111111111111'),
          '04_report_detail'));

  testWidgets('dashboard',
      (t) => shoot(t, DashboardPage(api: api), '05_dashboard'));

  testWidgets('public lookup',
      (t) => shoot(t, PublicLookupPage(api: api), '06_lookup'));

  testWidgets('settings',
      (t) => shoot(t, SettingsPage(api: api), '07_settings'));
}
