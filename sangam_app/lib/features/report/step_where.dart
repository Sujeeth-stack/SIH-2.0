import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../widgets/labeled_field.dart';
import 'draft.dart';

/// Step 2 — where it is, and what proof there is.
///
/// GPS is a convenience, never a gate: if the device refuses or the platform
/// has no location plugin, the reporter picks the district by hand and the
/// report is just as valid.
class StepWhere extends StatefulWidget {
  final ReportDraft draft;
  final SangamApi api;
  final VoidCallback onChanged;

  const StepWhere({
    super.key,
    required this.draft,
    required this.api,
    required this.onChanged,
  });

  @override
  State<StepWhere> createState() => _StepWhereState();
}

class _StepWhereState extends State<StepWhere> {
  bool _locating = false;
  String? _locationError;
  List<CountRow> _districts = const [];

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    if (widget.draft.districtCode == null) _detectLocation();
  }

  Future<void> _loadDistricts() async {
    try {
      final d = await widget.api.districts();
      if (mounted) setState(() => _districts = d);
    } catch (_) {
      // The manual picker simply stays empty; GPS or a later retry still works.
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location is switched off on this device.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission was not given.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final place = await widget.api.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        widget.draft.latitude = pos.latitude;
        widget.draft.longitude = pos.longitude;
        widget.draft.districtCode = place.districtCode;
        widget.draft.locationLabel = place.label;
        _locating = false;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Could not detect your location. Choose the district below.';
      });
    }
  }

  Future<void> _pickDistrict() async {
    final chosen = await showModalBottomSheet<CountRow>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                child: Row(
                  children: [
                    Text('Choose district',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: _districts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) => ListTile(
                    minTileHeight: 52,
                    title: Text(_districts[i].label),
                    onTap: () => Navigator.pop(ctx, _districts[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        widget.draft.districtCode = chosen.key;
        widget.draft.locationLabel = '${chosen.label}, Jharkhand';
        _locationError = null;
      });
      widget.onChanged();
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    if (widget.draft.photoCount >= AppConfig.maxPhotos) {
      _toast('You can attach up to ${AppConfig.maxPhotos} photos.');
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 75, // keeps a village 2G upload realistic
      );
      if (picked == null) return;
      setState(() => widget.draft.attachments.add(
            Attachment(path: picked.path, kind: 'photo', name: picked.name),
          ));
      widget.onChanged();
    } catch (_) {
      _toast('Camera is not available on this device.');
    }
  }

  Future<void> _addVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked == null) return;
      setState(() => widget.draft.attachments.add(
            Attachment(path: picked.path, kind: 'video', name: picked.name),
          ));
      widget.onChanged();
    } catch (_) {
      _toast('Video recording is not available on this device.');
    }
  }

  Future<void> _addFile(String kind) async {
    try {
      final picked = await FilePicker.pickFile(
        type: kind == 'audio' ? FileType.audio : FileType.any,
      );
      // `path` is null when the pick is not a local file (a cloud provider,
      // for instance); there is nothing to upload in that case.
      final path = picked?.path;
      if (picked == null || path == null) {
        if (picked != null) _toast('Pick a file saved on this device.');
        return;
      }
      setState(() => widget.draft.attachments.add(
            Attachment(path: path, kind: kind, name: picked.name),
          ));
      widget.onChanged();
    } catch (_) {
      _toast('Could not open the file picker.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        LabeledField(
          label: 'Where is it?',
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.primary),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _locating
                      ? Text('Detecting your location…', style: t.bodyMedium)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.locationLabel ?? 'Location not set',
                              style: t.bodyLarge,
                            ),
                            if (d.latitude != null)
                              Text(
                                '${d.latitude!.toStringAsFixed(4)}, '
                                '${d.longitude!.toStringAsFixed(4)}',
                                style: t.bodySmall,
                              ),
                          ],
                        ),
                ),
                if (_locating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Detect location again',
                    icon: const Icon(Icons.my_location_outlined),
                    onPressed: _detectLocation,
                  ),
              ],
            ),
          ),
        ),
        if (_locationError != null) ...[
          const SizedBox(height: Gap.sm),
          Text(_locationError!, style: t.bodySmall?.copyWith(color: AppColors.danger)),
        ],
        const SizedBox(height: Gap.md),
        OutlinedButton.icon(
          onPressed: _districts.isEmpty ? null : _pickDistrict,
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: Text(d.districtCode == null ? 'Choose district' : 'Adjust district'),
        ),

        const SizedBox(height: Gap.xl),
        LabeledField(
          label: 'Add proof',
          optional: true,
          helper: 'Photos help an officer act faster. Up to ${AppConfig.maxPhotos}.',
          child: Column(
            children: [
              _AttachmentGrid(
                attachments: d.attachments,
                onRemove: (i) {
                  setState(() => d.attachments.removeAt(i));
                  widget.onChanged();
                },
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  _AddButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: () => _addPhoto(ImageSource.camera),
                  ),
                  _AddButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _addPhoto(ImageSource.gallery),
                  ),
                  _AddButton(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    onTap: _addVideo,
                  ),
                  _AddButton(
                    icon: Icons.mic_none_outlined,
                    label: 'Voice note',
                    onTap: () => _addFile('audio'),
                  ),
                  _AddButton(
                    icon: Icons.attach_file_outlined,
                    label: 'Document',
                    onTap: () => _addFile('doc'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xxl),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      ),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(int) onRemove;
  const _AttachmentGrid({required this.attachments, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Nothing attached yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: List.generate(attachments.length, (i) {
        final a = attachments[i];
        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: a.kind == 'photo'
                    ? Image.file(File(a.path), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _FileTile(kind: 'photo'))
                    : _FileTile(kind: a.kind),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(i),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16),
                    ),
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

class _FileTile extends StatelessWidget {
  final String kind;
  const _FileTile({required this.kind});

  IconData get _icon => switch (kind) {
        'video' => Icons.videocam_outlined,
        'audio' => Icons.mic_none_outlined,
        'doc' => Icons.description_outlined,
        _ => Icons.image_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(_icon, color: AppColors.textSecondary),
    );
  }
}
