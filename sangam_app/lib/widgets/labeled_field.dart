import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Label sits above the field, never floating inside it — easier to read at
/// arm's length and it survives translation into Hindi without clipping.
class LabeledField extends StatelessWidget {
  final String label;
  final String? helper;
  final bool optional;
  final Widget child;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: t.titleMedium),
            if (optional) ...[
              const SizedBox(width: Gap.sm),
              Text('Optional', style: t.bodySmall),
            ],
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: Gap.xs),
          Text(helper!, style: t.bodySmall),
        ],
        const SizedBox(height: Gap.sm),
        child,
      ],
    );
  }
}
