import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/report_card.dart';
import '../report/report_flow_page.dart';
import 'report_detail_page.dart';

enum ReportFilter { all, inProgress, resolved }

/// Everything this device has sent. Pull down to refresh.
class MyReportsPage extends StatefulWidget {
  final SangamApi api;
  const MyReportsPage({super.key, required this.api});

  @override
  State<MyReportsPage> createState() => MyReportsPageState();
}

class MyReportsPageState extends State<MyReportsPage> {
  List<Problem>? _reports;
  String? _error;
  ReportFilter _filter = ReportFilter.all;

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
        _reports = list;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  List<Problem> get _visible {
    final all = _reports ?? const <Problem>[];
    return switch (_filter) {
      ReportFilter.all => all,
      ReportFilter.inProgress =>
        all.where((p) => ProblemStatus.isOpen(p.status)).toList(),
      ReportFilter.resolved =>
        all.where((p) => ProblemStatus.isResolved(p.status)).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null && _reports == null) {
      return ErrorView(message: _error!, onRetry: refresh);
    }
    if (_reports == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _FilterRow(
          value: _filter,
          counts: _reports!,
          onChanged: (f) => setState(() => _filter = f),
        ),
        const Divider(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: _visible.isEmpty
                ? ListView(
                    // A ListView so pull-to-refresh still works when empty.
                    children: [
                      SizedBox(
                        height: 380,
                        child: EmptyState(
                          icon: Icons.inbox_outlined,
                          message: _reports!.isEmpty
                              ? 'You have not sent any reports yet.'
                              : 'No reports in this filter.',
                          actionLabel:
                              _reports!.isEmpty ? 'Report a problem' : null,
                          onAction: _reports!.isEmpty
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReportFlowPage(api: widget.api),
                                    ),
                                  );
                                  refresh();
                                }
                              : null,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Gap.lg),
                    itemCount: _visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (_, i) {
                      final p = _visible[i];
                      return ReportCard(
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
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final ReportFilter value;
  final List<Problem> counts;
  final ValueChanged<ReportFilter> onChanged;

  const _FilterRow({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      ReportFilter.all: 'All (${counts.length})',
      ReportFilter.inProgress:
          'In progress (${counts.where((p) => ProblemStatus.isOpen(p.status)).length})',
      ReportFilter.resolved:
          'Resolved (${counts.where((p) => ProblemStatus.isResolved(p.status)).length})',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: ReportFilter.values.map((f) {
          final selected = f == value;
          return Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: ChoiceChip(
              label: Text(labels[f]!),
              selected: selected,
              onSelected: (_) => onChanged(f),
              labelStyle: TextStyle(
                fontSize: 14,
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
