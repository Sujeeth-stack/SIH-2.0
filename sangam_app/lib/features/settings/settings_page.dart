import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../data/reporter_store.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/section_header.dart';

class SettingsPage extends StatefulWidget {
  final SangamApi api;
  const SettingsPage({super.key, required this.api});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReporterProfile _profile = const ReporterProfile();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ReporterStore.load();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ReporterStore.save(_profile);
    try {
      await widget.api.updateReporter(_profile);
    } on ApiException {
      // Saved on the phone regardless; the server picks it up on the next report.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your details are saved on this phone')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: [
                const SectionHeader('Your details'),
                Text(
                  'Optional, and never checked by the app. It only helps an '
                  'officer reach you about a report.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Name',
                  optional: true,
                  child: TextFormField(
                    initialValue: _profile.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Your name'),
                    onChanged: (v) =>
                        _profile = _profile.copyWith(name: v),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Phone',
                  optional: true,
                  child: TextFormField(
                    initialValue: _profile.phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Phone number'),
                    onChanged: (v) =>
                        _profile = _profile.copyWith(phone: v),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                LabeledField(
                  label: 'Reporting on behalf of',
                  child: Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: ReporterProfile.types.entries.map((e) {
                      final selected = _profile.type == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: selected,
                        onSelected: (_) => setState(
                            () => _profile = _profile.copyWith(type: e.key)),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          color:
                              selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.primary : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_profile.type != 'CITIZEN') ...[
                  const SizedBox(height: Gap.lg),
                  LabeledField(
                    label: 'Group or office',
                    optional: true,
                    child: TextFormField(
                      initialValue: _profile.org,
                      decoration:
                          const InputDecoration(hintText: 'Name of the office'),
                      onChanged: (v) =>
                          _profile = _profile.copyWith(org: v),
                    ),
                  ),
                ],
                const SizedBox(height: Gap.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save details'),
                ),

                const SizedBox(height: Gap.xxl),
                const SectionHeader('About'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(label: 'App', value: 'SANGAM · Phase 1'),
                        const SizedBox(height: Gap.md),
                        _Row(label: 'Server', value: widget.api.baseUrl),
                        const SizedBox(height: Gap.md),
                        Row(
                          children: [
                            Expanded(
                              child: _Row(
                                label: 'This device',
                                value: widget.api.deviceId,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy device ID',
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: widget.api.deviceId));
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Device ID copied')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  'There is no login. This phone is remembered by a random ID so '
                  '"My reports" can find your reports again. Reinstalling the app '
                  'makes a new ID — your reports stay findable by their report ID.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: Gap.xxl),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: t.bodyMedium),
      ],
    );
  }
}
