// Plain data holders mirroring the API payloads. Kept hand-written (no
// codegen) so the shapes stay readable next to the endpoint contract.

int? _asInt(dynamic v) => v is int ? v : (v is String ? int.tryParse(v) : null);
double? _asDouble(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
DateTime? _asDate(dynamic v) =>
    v is String ? DateTime.tryParse(v) : null;

class Problem {
  final String problemId;
  final String publicRef;
  final String title;
  final String description;
  final String domain;
  final String status;
  final String? districtCode;
  final String? districtName;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final int? peopleAffected;
  final String? durationLabel;
  final String reporterType;
  final bool officialSource;
  final int mediaCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Problem({
    required this.problemId,
    required this.publicRef,
    required this.title,
    required this.description,
    required this.domain,
    required this.status,
    this.districtCode,
    this.districtName,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.peopleAffected,
    this.durationLabel,
    this.reporterType = 'CITIZEN',
    this.officialSource = false,
    this.mediaCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Problem.fromJson(Map<String, dynamic> j) => Problem(
        problemId: j['problem_id'] as String,
        publicRef: (j['public_ref'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        domain: (j['domain'] ?? 'OTHER') as String,
        status: (j['status'] ?? 'SUBMITTED') as String,
        districtCode: j['district_code'] as String?,
        districtName: j['district_name'] as String?,
        locationLabel: j['location_label'] as String?,
        latitude: _asDouble(j['latitude']),
        longitude: _asDouble(j['longitude']),
        peopleAffected: _asInt(j['people_affected']),
        durationLabel: j['duration_label'] as String?,
        reporterType: (j['reporter_type'] ?? 'CITIZEN') as String,
        officialSource: j['official_source'] == true,
        mediaCount: _asInt(j['media_count']) ?? 0,
        createdAt: _asDate(j['created_at']),
        updatedAt: _asDate(j['updated_at']),
      );
}

class MediaItem {
  final String mediaId;
  final String kind; // photo | video | audio | doc
  final String? mimeType;
  final int byteSize;
  final String url; // path relative to the API base

  const MediaItem({
    required this.mediaId,
    required this.kind,
    required this.url,
    this.mimeType,
    this.byteSize = 0,
  });

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        mediaId: j['media_id'] as String,
        kind: (j['kind'] ?? 'photo') as String,
        url: (j['url'] ?? '') as String,
        mimeType: j['mime_type'] as String?,
        byteSize: _asInt(j['byte_size']) ?? 0,
      );
}

class StatusEvent {
  final String status;
  final String? note;
  final String? actor;
  final DateTime? createdAt;

  const StatusEvent({
    required this.status,
    this.note,
    this.actor,
    this.createdAt,
  });

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: (j['status'] ?? '') as String,
        note: j['note'] as String?,
        actor: j['actor'] as String?,
        createdAt: _asDate(j['created_at']),
      );

  /// "officer:BDO Dumka" reads as "BDO Dumka" in the timeline.
  String get actorLabel {
    final a = actor;
    if (a == null || a.isEmpty) return 'System';
    if (a.startsWith('officer:')) return a.substring(8);
    if (a == 'citizen') return 'You';
    return a[0].toUpperCase() + a.substring(1);
  }
}

class ProblemDetail {
  final Problem problem;
  final List<MediaItem> media;
  final List<StatusEvent> history;

  const ProblemDetail({
    required this.problem,
    required this.media,
    required this.history,
  });

  factory ProblemDetail.fromJson(Map<String, dynamic> j) => ProblemDetail(
        problem: Problem.fromJson(j['problem'] as Map<String, dynamic>),
        media: ((j['media'] ?? []) as List)
            .map((m) => MediaItem.fromJson(m as Map<String, dynamic>))
            .toList(),
        history: ((j['history'] ?? []) as List)
            .map((h) => StatusEvent.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class DomainOption {
  final String code;
  final String label;
  const DomainOption(this.code, this.label);

  factory DomainOption.fromJson(Map<String, dynamic> j) =>
      DomainOption(j['code'] as String, j['label'] as String);
}

class GeoPlace {
  final String districtCode;
  final String districtName;
  final String label;

  const GeoPlace({
    required this.districtCode,
    required this.districtName,
    required this.label,
  });

  factory GeoPlace.fromJson(Map<String, dynamic> j) => GeoPlace(
        districtCode: (j['district_code'] ?? '') as String,
        districtName: (j['district_name'] ?? '') as String,
        label: (j['label'] ?? '') as String,
      );
}

class CountRow {
  final String key;
  final String label;
  final int count;
  const CountRow(this.key, this.label, this.count);
}

class AnalyticsSummary {
  final int total;
  final int open;
  final int resolved;
  final List<CountRow> byStatus;
  final List<CountRow> byDistrict;
  final List<CountRow> byDomain;

  const AnalyticsSummary({
    required this.total,
    required this.open,
    required this.resolved,
    required this.byStatus,
    required this.byDistrict,
    required this.byDomain,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] ?? {}) as Map<String, dynamic>;
    List<CountRow> rows(String field, String keyName, String labelName) =>
        ((j[field] ?? []) as List).map((e) {
          final m = e as Map<String, dynamic>;
          return CountRow(
            (m[keyName] ?? '') as String,
            (m[labelName] ?? m[keyName] ?? '') as String,
            _asInt(m['count']) ?? 0,
          );
        }).toList();

    return AnalyticsSummary(
      total: _asInt(totals['total']) ?? 0,
      open: _asInt(totals['open']) ?? 0,
      resolved: _asInt(totals['resolved']) ?? 0,
      byStatus: rows('by_status', 'status', 'status'),
      byDistrict: rows('by_district', 'code', 'name'),
      byDomain: rows('by_domain', 'domain', 'domain'),
    );
  }
}

class ReporterProfile {
  final String? name;
  final String? phone;
  final String type;
  final String? org;

  const ReporterProfile({this.name, this.phone, this.type = 'CITIZEN', this.org});

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (phone == null || phone!.isEmpty) &&
      (org == null || org!.isEmpty);

  static const types = <String, String>{
    'CITIZEN': 'Citizen',
    'COMMUNITY_GROUP': 'Community group',
    'PRI': 'Panchayat',
    'ULB': 'Urban local body',
    'GOVT_DEPT': 'Government department',
  };

  ReporterProfile copyWith({String? name, String? phone, String? type, String? org}) =>
      ReporterProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        type: type ?? this.type,
        org: org ?? this.org,
      );
}
