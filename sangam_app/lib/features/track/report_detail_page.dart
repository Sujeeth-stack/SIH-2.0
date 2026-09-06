import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_chip.dart';

/// One report: its evidence, where it is, and every update on it.
///
/// Reachable either from "My reports" or from a public ID lookup — the same
/// screen either way, because transparency means a stranger sees what the
/// reporter sees.
class ReportDetailPage extends StatefulWidget {
  final SangamApi api;
  final String? problemId;
  final ProblemDetail? preloaded;

  const ReportDetailPage({
    super.key,
    required this.api,
    this.problemId,
    this.preloaded,
  }) : assert(problemId != null || preloaded != null);

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  ProblemDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detail = widget.preloaded;
    if (_detail == null) _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.problem(widget.problemId!);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Copy report ID',
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: d.problem.publicRef),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied ${d.problem.publicRef}')),
                );
              },
            ),
        ],
      ),
      body: _buildBody(d),
    );
  }

  Widget _buildBody(ProblemDetail? d) {
    if (_error != null && d == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (d == null) return const Center(child: CircularProgressIndicator());

    final p = d.problem;
    final t = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(p.title, style: t.titleLarge)),
              const SizedBox(width: Gap.md),
              StatusChip(p.status),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            joinParts([p.publicRef, friendlyDate(p.createdAt)]),
            style: t.bodySmall,
          ),

          if (p.description.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            Text(p.description, style: t.bodyLarge),
          ],

          if (d.media.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionHeader('Evidence'),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.media.length,
                separatorBuilder: (_, __) => const SizedBox(width: Gap.md),
                itemBuilder: (_, i) => _MediaTile(
                  item: d.media[i],
                  url: widget.api.mediaUrl(d.media[i].url),
                ),
              ),
            ),
          ],

          const SizedBox(height: Gap.xl),
          const SectionHeader('Where'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.primary),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.locationLabel ?? p.districtName ?? 'Not recorded',
                          style: t.bodyLarge,
                        ),
                        if (p.latitude != null)
                          Text(
                            '${p.latitude!.toStringAsFixed(4)}, '
                            '${p.longitude!.toStringAsFixed(4)}',
                            style: t.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (p.peopleAffected != null || p.durationLabel != null) ...[
            const SizedBox(height: Gap.xl),
            const SectionHeader('Scale'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  children: [
                    if (p.peopleAffected != null)
                      _FactRow('People affected', '${p.peopleAffected}'),
                    if (p.durationLabel != null) ...[
                      if (p.peopleAffected != null) const SizedBox(height: Gap.md),
                      _FactRow(
                        'Going on for',
                        _durationLabel(p.durationLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: Gap.xl),
          const SectionHeader('Updates'),
          if (d.history.isEmpty)
            Text('No updates yet.', style: t.bodySmall)
          else
            _Timeline(events: d.history.reversed.toList()),

          const SizedBox(height: Gap.xxl),
        ],
      ),
    );
  }

  static String _durationLabel(String code) => switch (code) {
        'LESS_THAN_WEEK' => 'Less than a week',
        'ONE_TO_FOUR_WEEKS' => '1–4 weeks',
        'MORE_THAN_MONTH' => 'More than a month',
        'MORE_THAN_YEAR' => 'More than a year',
        _ => code,
      };
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Text(value, style: t.bodyMedium),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final String url;
  const _MediaTile({required this.item, required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.kind == 'photo'
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _MediaPlaceholder(kind: 'photo'),
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            )
          : _MediaPlaceholder(kind: item.kind),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final String kind;
  const _MediaPlaceholder({required this.kind});

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      'video' => Icons.play_circle_outline,
      'audio' => Icons.mic_none_outlined,
      'doc' => Icons.description_outlined,
      _ => Icons.image_outlined,
    };
    return Center(child: Icon(icon, size: 32, color: AppColors.textSecondary));
  }
}

/// Newest update at the top, each with who wrote it.
class _Timeline extends StatelessWidget {
  final List<StatusEvent> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      children: List.generate(events.length, (i) {
        final e = events[i];
        final (_, fg) = ProblemStatus.colors(e.status);
        final isLast = i == events.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 1, color: AppColors.border),
                    ),
                ],
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : Gap.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ProblemStatus.label(e.status), style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        joinParts([e.actorLabel, friendlyDate(e.createdAt)]),
                        style: t.bodySmall,
                      ),
                      if (e.note != null && e.note!.isNotEmpty) ...[
                        const SizedBox(height: Gap.sm),
                        Text(e.note!, style: t.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
