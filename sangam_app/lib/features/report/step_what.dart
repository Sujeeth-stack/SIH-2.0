import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/labeled_field.dart';
import 'draft.dart';

/// Step 1 — what is wrong.
class StepWhat extends StatelessWidget {
  final ReportDraft draft;
  final List<DomainOption> domains;
  final VoidCallback onChanged;

  const StepWhat({
    super.key,
    required this.draft,
    required this.domains,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        LabeledField(
          label: 'What is the problem?',
          helper: 'A short line is enough — for example, "Handpump dry for three weeks".',
          child: TextFormField(
            initialValue: draft.title,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Handpump dry for three weeks',
              counterText: '',
            ),
            onChanged: (v) {
              draft.title = v;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: Gap.xl),
        LabeledField(
          label: 'Tell us more',
          optional: true,
          helper: 'Who it affects, since when, what has been tried.',
          child: TextFormField(
            initialValue: draft.description,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'The only handpump in the tola has run dry…',
            ),
            onChanged: (v) {
              draft.description = v;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: Gap.xl),
        LabeledField(
          label: 'Which area does it belong to?',
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: domains.map((d) {
              final selected = draft.domain == d.code;
              return ChoiceChip(
                label: Text(d.label),
                selected: selected,
                onSelected: (_) {
                  draft.domain = d.code;
                  onChanged();
                },
                labelStyle: TextStyle(
                  fontSize: 14,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: Gap.xxl),
      ],
    );
  }
}
