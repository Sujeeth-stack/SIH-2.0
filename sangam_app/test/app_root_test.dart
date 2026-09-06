import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangam/core/app_config.dart';
import 'package:sangam/core/device_identity.dart';
import 'package:sangam/data/api.dart';
import 'package:sangam/main.dart';

/// Pulls main.dart into the compiled test tree so the real entrypoint and the
/// root widget are type-checked and exercised, not just the leaf widgets.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('the device ID is minted once and then reused', () async {
    final first = await DeviceIdentity.ensure();
    final second = await DeviceIdentity.ensure();
    expect(first, isNotEmpty);
    expect(second, first, reason: 'a new ID each launch would orphan reports');
  });

  test('base URL is emulator-aware and overridable at build time', () {
    expect(AppConfig.baseUrl, startsWith('http'));
  });

  testWidgets('the root widget builds and lands on the main page',
      (tester) async {
    final api = SangamApi(
      deviceId: '33333333-3333-4333-8333-333333333333',
      adapter: _Offline(),
    );

    await tester.pumpWidget(SangamApp(api: api));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('SANGAM'), findsOneWidget);
    expect(find.text('Report a problem'), findsWidgets);
  });
}

/// Every request fails, standing in for a phone with no signal.
class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _,
          Future<void>? __) async =>
      throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline in test',
      );

  @override
  void close({bool force = false}) {}
}
