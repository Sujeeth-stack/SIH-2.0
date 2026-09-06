import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../core/server_store.dart';
import '../../data/reporter_store.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/section_header.dart';

class SettingsPage extends StatefulWidget {
  final SangamApi api;
  final ValueChanged<String>? onServerChanged;
  const SettingsPage({super.key, required this.api, this.onServerChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReporterProfile _profile = const ReporterProfile();
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _serverCtrl =
      TextEditingController(text: widget.api.baseUrl);
  String? _serverError;
  String? _serverStatus;
  bool _testing = false;

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  /// Saves the address and asks the app to rebuild against it. The connection
  /// is checked first so a typo is caught here rather than looking like every
  /// screen is broken.
  Future<void> _applyServer() async {
    final raw = _serverCtrl.text;
    final invalid = ServerStore.validate(raw);
    if (invalid != null) {
      setState(() {
        _serverError = invalid;
        _serverStatus = null;
      });
      return;
    }

    final url = ServerStore.normalise(raw);
    setState(() {
      _testing = true;
      _serverError = null;
      _serverStatus = null;
    });

    final probe = SangamApi(deviceId: widget.api.deviceId, baseUrl: url);
    try {
      await probe.analytics();
      await ServerStore.save(url);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _serverStatus = 'Connected. This phone now uses $url';
        _serverCtrl.text = url;
      });
      widget.onServerChanged?.call(url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _serverError = 'Could not reach that server. ${e.message}';
      });
    }
  }

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
                const SectionHeader('Server'),
                Text(
                  'Where this app sends reports. Change it if the team moves '
                  'the server to a new address.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: _serverCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'https://sangam.example.in',
                    errorText: _serverError,
                  ),
                ),
                if (_serverStatus != null) ...[
                  const SizedBox(height: Gap.sm),
                  Text(
                    _serverStatus!,
                    style: t.bodySmall?.copyWith(color: AppColors.success),
                  ),
                ],
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _testing ? null : _applyServer,
                        child: _testing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Test and save'),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing
                            ? null
                            : () async {
                                await ServerStore.reset();
                                if (!context.mounted) return;
                                final fallback = await ServerStore.load();
                                if (!context.mounted) return;
                                setState(() {
                                  _serverCtrl.text = fallback;
                                  _serverError = null;
                                  _serverStatus = 'Reset to the built-in address';
                                });
                                widget.onServerChanged?.call(fallback);
                              },
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Gap.xxl),
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
