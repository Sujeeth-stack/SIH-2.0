import 'package:intl/intl.dart';

final _dayMonth = DateFormat('d MMM yyyy');

/// "2 hours ago" for anything recent, an absolute date beyond a week —
/// villagers reading a week-old report care about the date, not the delta.
String friendlyDate(DateTime? when) {
  if (when == null) return '';
  final local = when.toLocal();
  final diff = DateTime.now().difference(local);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }
  return _dayMonth.format(local);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Joins the non-empty parts of a card subtitle with a middot.
String joinParts(List<String?> parts) =>
    parts.where((p) => p != null && p.trim().isNotEmpty).join(' · ');
