import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/report_card.dart';
import '../../widgets/section_header.dart';
import '../lookup/public_lookup_page.dart';
import '../report/report_flow_page.dart';
import '../settings/settings_page.dart';
import '../track/report_detail_page.dart';

/// The main page — the app opens straight here, no login of any kind.
class HomePage extends StatefulWidget {
  final SangamApi api;
  final VoidCallback onSeeAllReports;

  const HomePage({
    super.key,
    required this.api,
    required this.onSeeAllReports,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Problem>? _recent;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await widget.api.myReports();
      if (!mounted) return;
      setState(() {
        _recent = list;
        _offline = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _recent ??= const [];
        _offline = true;
      });
    }
  }

  Future<void> _startReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportFlowPage(api: widget.api)),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reports = _recent ?? const <Problem>[];
    final recent = reports.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SANGAM'),
        actions: [
          IconButton(
            tooltip: 'Look up a report by ID',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicLookupPage(api: widget.api),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(api: widget.api),
                ),
              );
              refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_offline) const _OfflineBanner(),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell the government what needs fixing',
                    style: t.headlineMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Send a problem from your village or ward. You get an ID to '
                    'follow what happens next.',
                    style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: Gap.xl),
                  FilledButton.icon(
                    onPressed: _startReport,
                    icon: const Icon(Icons.add),
                    label: const Text('Report a problem'),
                  ),
                  const SizedBox(height: Gap.xl),
                  _StatRow(reports: reports),
                  const SizedBox(height: Gap.xl),
                  SectionHeader(
                    'Recent reports',
                    actionLabel: reports.isEmpty ? null : 'See all',
                    onAction: reports.isEmpty ? null : widget.onSeeAllReports,
                  ),
                ],
              ),
            ),
            if (_recent == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recent.isEmpty)
              SizedBox(
                height: 260,
                child: EmptyState(
                  icon: Icons.description_outlined,
                  message: 'Nothing reported from this phone yet.',
                  actionLabel: 'Report a problem',
                  onAction: _startReport,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
                child: Column(
                  children: recent
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.md),
                          child: ReportCard(
                            title: p.title,
                            subtitle: joinParts([
                              p.districtName ?? p.locationLabel,
                              friendlyDate(p.createdAt),
                            ]),
                            status: p.status,
                            trailingNote: p.publicRef,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailPage(
                                    api: widget.api,
                                    problemId: p.problemId,
                                  ),
                                ),
                              );
                              refresh();
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slim strip, same shape as the sync banner in the spec — here it reports
/// that the server is unreachable, since Phase 1 writes straight to Postgres.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Cannot reach the server — pull down to try again.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<Problem> reports;
  const _StatRow({required this.reports});

  @override
  Widget build(BuildContext context) {
    final submitted = reports.length;
    final inProgress =
        reports.where((p) => ProblemStatus.isOpen(p.status)).length;
    final resolved =
        reports.where((p) => ProblemStatus.isResolved(p.status)).length;

    return Row(
      children: [
        Expanded(child: _Stat(label: 'Submitted', value: submitted)),
        const SizedBox(width: Gap.md),
        Expanded(child: _Stat(label: 'In progress', value: inProgress)),
        const SizedBox(width: Gap.md),
        Expanded(child: _Stat(label: 'Resolved', value: resolved)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg, horizontal: Gap.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$value', style: t.titleLarge),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
