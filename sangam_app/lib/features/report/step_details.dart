import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/labeled_field.dart';
import 'draft.dart';

/// Step 3 — scale, optional reporter details, consent.
class StepDetails extends StatelessWidget {
  final ReportDraft draft;
  final VoidCallback onChanged;

  const StepDetails({super.key, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        LabeledField(
          label: 'About how many people are affected?',
          optional: true,
          child: TextFormField(
            initialValue: draft.peopleAffected?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'For example, 180'),
            onChanged: (v) {
              draft.peopleAffected = int.tryParse(v.trim());
              onChanged();
            },
          ),
        ),
        const SizedBox(height: Gap.xl),
        LabeledField(
          label: 'How long has this been going on?',
          optional: true,
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: ReportDraft.durations.entries.map((e) {
              final selected = draft.durationLabel == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) {
                  draft.durationLabel = selected ? null : e.key;
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

        const SizedBox(height: Gap.xl),
        // Reporter details — self-declared and unverified by design.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your details', style: t.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  'Optional. It helps an officer call you back. '
                  'We save it on this phone so you need not type it again.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: Gap.lg),
                TextFormField(
                  initialValue: draft.reporter.name,
                  decoration: const InputDecoration(hintText: 'Your name'),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    draft.reporter = draft.reporter.copyWith(name: v);
                    onChanged();
                  },
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  initialValue: draft.reporter.phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone number'),
                  onChanged: (v) {
                    draft.reporter = draft.reporter.copyWith(phone: v);
                    onChanged();
                  },
                ),
                const SizedBox(height: Gap.lg),
                Text('Reporting on behalf of', style: t.bodySmall),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: ReporterProfile.types.entries.map((e) {
                    final selected = draft.reporter.type == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      onSelected: (_) {
                        draft.reporter = draft.reporter.copyWith(type: e.key);
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
                if (draft.reporter.type != 'CITIZEN') ...[
                  const SizedBox(height: Gap.md),
                  TextFormField(
                    initialValue: draft.reporter.org,
                    decoration: const InputDecoration(
                      hintText: 'Name of the group or office',
                    ),
                    onChanged: (v) {
                      draft.reporter = draft.reporter.copyWith(org: v);
                      onChanged();
                    },
                  ),
                  const SizedBox(height: Gap.sm),
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'This is what you have told us, and it is not checked here. '
                      'A government officer confirms the source before it counts as official.',
                      style: t.bodySmall?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: Gap.xl),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            draft.consent = !draft.consent;
            onChanged();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: draft.consent,
                  onChanged: (v) {
                    draft.consent = v ?? false;
                    onChanged();
                  },
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'I agree that this report and its photos may be shared with '
                      'government departments and partners working on a solution.',
                      style: t.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xxl),
      ],
    );
  }
}
