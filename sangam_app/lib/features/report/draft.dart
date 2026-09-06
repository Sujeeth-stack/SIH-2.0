import 'package:uuid/uuid.dart';

import '../../data/models.dart';

class Attachment {
  final String path;
  final String kind; // photo | video | audio | doc
  final String name;
  const Attachment({required this.path, required this.kind, required this.name});
}

/// Everything the three steps collect, held in one object so Back never
/// loses what was already typed.
class ReportDraft {
  /// Minted once, up front. The server treats POST /problems as idempotent on
  /// this id, so a retry after a timeout cannot create a second report.
  final String problemId = const Uuid().v4();

  String title = '';
  String description = '';
  String domain = '';

  double? latitude;
  double? longitude;
  String? districtCode;
  String? locationLabel;

  final List<Attachment> attachments = [];

  int? peopleAffected;
  String? durationLabel;
  bool consent = false;

  ReporterProfile reporter = const ReporterProfile();

  int get photoCount => attachments.where((a) => a.kind == 'photo').length;

  bool get step1Valid => title.trim().length >= 3 && domain.isNotEmpty;
  bool get step2Valid => districtCode != null || locationLabel != null;
  bool get step3Valid => consent;

  static const durations = <String, String>{
    'LESS_THAN_WEEK': 'Less than a week',
    'ONE_TO_FOUR_WEEKS': '1–4 weeks',
    'MORE_THAN_MONTH': 'More than a month',
    'MORE_THAN_YEAR': 'More than a year',
  };
}
