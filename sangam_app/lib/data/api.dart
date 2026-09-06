import 'dart:io';

import 'package:dio/dio.dart';

import '../core/app_config.dart';
import 'models.dart';

/// Raised for anything the user should see a sentence about.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  const ApiException(this.message, {this.statusCode, this.code});

  bool get isOffline => statusCode == null;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

/// The whole §3 contract in one place. No Authorization header anywhere —
/// the device id rides along as X-Device-Id purely so the server can attribute
/// and rate-limit writes.
class SangamApi {
  final Dio _dio;
  final String deviceId;

  /// [adapter] exists so widget tests can drive the UI without real network
  /// I/O, which a `testWidgets` fake clock would never let complete.
  SangamApi({required this.deviceId, String? baseUrl, HttpClientAdapter? adapter})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 60),
          headers: {'X-Device-Id': deviceId},
          // Let non-2xx through so errors are shaped here, not thrown raw.
          validateStatus: (s) => s != null && s < 500,
        )) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  String get baseUrl => _dio.options.baseUrl;

  /// Absolute URL for a media path returned by the API.
  String mediaUrl(String path) =>
      path.startsWith('http') ? path : '${_dio.options.baseUrl}$path';

  Never _throwFrom(Response res) {
    final data = res.data;
    String message = 'Something went wrong. Please try again.';
    String? code;
    if (data is Map && data['error'] is Map) {
      final e = data['error'] as Map;
      message = (e['message'] ?? message).toString();
      code = e['code']?.toString();
    }
    throw ApiException(message, statusCode: res.statusCode, code: code);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.error is SocketException) {
        throw const ApiException(
          'Cannot reach the SANGAM server. Check your connection and try again.',
        );
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw const ApiException('The server took too long to respond.');
      }
      throw ApiException(e.message ?? 'Network error');
    }
  }

  // ------------------------------------------------------------- devices
  /// Fire-and-forget on launch; a failure here must never block the UI.
  Future<void> registerDevice({String? language}) => _guard(() async {
        await _dio.post('/devices', data: {
          'device_id': deviceId,
          'platform': _platform,
          if (language != null) 'language': language,
        });
      });

  Future<void> updateReporter(ReporterProfile p) => _guard(() async {
        final res = await _dio.patch('/devices/$deviceId', data: {
          'reporter_name': p.name,
          'reporter_phone': p.phone,
          'reporter_type': p.type,
          'reporter_org': p.org,
        });
        if (res.statusCode != 200) _throwFrom(res);
      });

  static String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'android';
  }

  // ------------------------------------------------------------ reference
  Future<List<DomainOption>> domains() => _guard(() async {
        final res = await _dio.get('/reference/domains');
        if (res.statusCode != 200) _throwFrom(res);
        return ((res.data['domains'] ?? []) as List)
            .map((e) => DomainOption.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<CountRow>> districts() => _guard(() async {
        final res = await _dio.get('/reference/districts');
        if (res.statusCode != 200) _throwFrom(res);
        return ((res.data['districts'] ?? []) as List).map((e) {
          final m = e as Map<String, dynamic>;
          return CountRow(m['code'] as String, m['name'] as String, 0);
        }).toList();
      });

  // ------------------------------------------------------------- problems
  /// [problemId] is minted on the device so a retry after a timeout is
  /// idempotent rather than a duplicate report.
  Future<Problem> submitProblem({
    required String problemId,
    required String title,
    required String description,
    required String domain,
    String? districtCode,
    String? locationLabel,
    double? latitude,
    double? longitude,
    int? peopleAffected,
    String? durationLabel,
    bool consent = false,
  }) =>
      _guard(() async {
        final res = await _dio.post('/problems', data: {
          'problem_id': problemId,
          'device_id': deviceId,
          'platform': _platform,
          'title': title,
          'description': description,
          'domain': domain,
          'district_code': districtCode,
          'location_label': locationLabel,
          'latitude': latitude,
          'longitude': longitude,
          'people_affected': peopleAffected,
          'duration_label': durationLabel,
          'consent': consent,
        });
        if (res.statusCode != 200 && res.statusCode != 201) _throwFrom(res);
        return Problem.fromJson(res.data['problem'] as Map<String, dynamic>);
      });

  Future<List<Problem>> myReports({DateTime? since}) => _guard(() async {
        final res = await _dio.get('/problems', queryParameters: {
          'device_id': deviceId,
          if (since != null) 'since': since.toUtc().toIso8601String(),
        });
        if (res.statusCode != 200) _throwFrom(res);
        return ((res.data['problems'] ?? []) as List)
            .map((e) => Problem.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<ProblemDetail> problem(String problemId) => _guard(() async {
        final res = await _dio.get('/problems/$problemId');
        if (res.statusCode != 200) _throwFrom(res);
        return ProblemDetail.fromJson(res.data as Map<String, dynamic>);
      });

  Future<ProblemDetail> problemByRef(String publicRef) => _guard(() async {
        final res = await _dio.get('/problems/ref/${publicRef.trim()}');
        if (res.statusCode == 404) {
          throw const ApiException(
            'No report found with that ID. Check the letters and numbers and try again.',
            statusCode: 404,
          );
        }
        if (res.statusCode != 200) _throwFrom(res);
        return ProblemDetail.fromJson(res.data as Map<String, dynamic>);
      });

  // ---------------------------------------------------------------- media
  Future<MediaItem> uploadMedia({
    required String problemId,
    required String filePath,
    required String kind,
  }) =>
      _guard(() async {
        final form = FormData.fromMap({
          'kind': kind,
          'file': await MultipartFile.fromFile(filePath),
        });
        final res = await _dio.post('/problems/$problemId/media', data: form);
        if (res.statusCode != 201) _throwFrom(res);
        return MediaItem.fromJson(res.data['media'] as Map<String, dynamic>);
      });

  // ------------------------------------------------------------------ geo
  Future<GeoPlace> reverseGeocode(double lat, double lon) => _guard(() async {
        final res = await _dio
            .get('/geo/reverse', queryParameters: {'lat': lat, 'lon': lon});
        if (res.statusCode != 200) _throwFrom(res);
        return GeoPlace.fromJson(res.data as Map<String, dynamic>);
      });

  // ------------------------------------------------------------ analytics
  Future<AnalyticsSummary> analytics() => _guard(() async {
        final res = await _dio.get('/analytics/summary');
        if (res.statusCode != 200) _throwFrom(res);
        return AnalyticsSummary.fromJson(res.data as Map<String, dynamic>);
      });
}
