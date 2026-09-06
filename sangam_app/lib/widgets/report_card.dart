import 'package:flutter/material.dart';

import '../core/status.dart';
import '../core/theme.dart';
import 'status_chip.dart';

/// The one memorable element in the whole app: a quiet white card with a
/// coloured rail down its left edge that tracks the report's status.
class ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final String? trailingNote;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.trailingNote,
  });

  @override
  Widget build(BuildContext context) {
    final (_, fg) = ProblemStatus.colors(status);
    final t = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The status rail.
              Container(width: 4, color: fg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium,
                            ),
                          ),
                          const SizedBox(width: Gap.md),
                          StatusChip(status),
                        ],
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                      if (trailingNote != null) ...[
                        const SizedBox(height: Gap.sm),
                        Text(
                          trailingNote!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
