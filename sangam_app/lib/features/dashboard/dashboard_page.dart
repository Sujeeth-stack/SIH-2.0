import 'package:flutter/material.dart';

import '../../core/status.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../widgets/error_view.dart';
import '../../widgets/section_header.dart';

/// Read-open public analytics. No role check in Phase 1 — anyone may see the
/// shape of what the district is reporting.
class DashboardPage extends StatefulWidget {
  final SangamApi api;
  const DashboardPage({super.key, required this.api});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  AnalyticsSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final s = await widget.api.analytics();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null && _summary == null) {
      return ErrorView(message: _error!, onRetry: refresh);
    }
    final s = _summary;
    if (s == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Row(
            children: [
              Expanded(child: _Total(label: 'Total', value: s.total)),
              const SizedBox(width: Gap.md),
              Expanded(child: _Total(label: 'Open', value: s.open)),
              const SizedBox(width: Gap.md),
              Expanded(child: _Total(label: 'Resolved', value: s.resolved)),
            ],
          ),
          const SizedBox(height: Gap.xl),
          const SectionHeader('Reports by district'),
          _BarList(rows: s.byDistrict, emptyLabel: 'No reports yet.'),
          const SizedBox(height: Gap.xl),
          const SectionHeader('Reports by category'),
          _BarList(
            rows: s.byDomain
                .map((r) => CountRow(r.key, _domainLabel(r.key), r.count))
                .toList(),
            emptyLabel: 'No reports yet.',
          ),
          const SizedBox(height: Gap.xl),
          const SectionHeader('Status breakdown'),
          _BarList(
            rows: s.byStatus
                .map((r) => CountRow(r.key, ProblemStatus.label(r.key), r.count))
                .toList(),
            emptyLabel: 'No reports yet.',
            colorFor: (key) => ProblemStatus.colors(key).$2,
          ),
          const SizedBox(height: Gap.xxl),
        ],
      ),
    );
  }

  static String _domainLabel(String code) => switch (code) {
        'WATER' => 'Water supply',
        'SANITATION' => 'Sanitation',
        'ROADS' => 'Roads & transport',
        'ELECTRICITY' => 'Electricity',
        'HEALTH' => 'Health',
        'EDUCATION' => 'Education',
        'AGRICULTURE' => 'Agriculture',
        'LIVELIHOOD' => 'Livelihood',
        'ENVIRONMENT' => 'Environment',
        'CONNECTIVITY' => 'Phone & internet',
        'OTHER' => 'Something else',
        _ => code,
      };
}

class _Total extends StatelessWidget {
  final String label;
  final int value;
  const _Total({required this.label, required this.value});

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
          Text('$value', style: t.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
  }
}

/// Horizontal bars drawn from the token set — no chart library, so the
/// dashboard stays as quiet as the rest of the app.
class _BarList extends StatelessWidget {
  final List<CountRow> rows;
  final String emptyLabel;
  final Color Function(String key)? colorFor;

  const _BarList({
    required this.rows,
    required this.emptyLabel,
    this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (rows.isEmpty) {
      return Text(emptyLabel, style: t.bodySmall);
    }

    final max = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: List.generate(rows.length, (i) {
            final r = rows[i];
            final colour = colorFor?.call(r.key) ?? AppColors.primary;
            return Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.label, style: t.bodyMedium)),
                      Text('${r.count}', style: t.titleMedium),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : r.count / max,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceAlt,
                      color: colour,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
