import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../data/reporter_store.dart';
import '../../widgets/error_view.dart';
import 'draft.dart';
import 'step_details.dart';
import 'step_what.dart';
import 'step_where.dart';
import 'submitted_page.dart';

/// The 3-step submit. A slim progress bar under the app bar, a "Step n of 3"
/// caption, and Back / Next pinned to a bottom bar.
class ReportFlowPage extends StatefulWidget {
  final SangamApi api;
  const ReportFlowPage({super.key, required this.api});

  @override
  State<ReportFlowPage> createState() => _ReportFlowPageState();
}

class _ReportFlowPageState extends State<ReportFlowPage> {
  final _draft = ReportDraft();
  int _step = 0;
  bool _submitting = false;
  String? _loadError;

  List<DomainOption> _domains = const [];
  bool _loadingDomains = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final saved = await ReporterStore.load();
      final domains = await widget.api.domains();
      if (!mounted) return;
      setState(() {
        _draft.reporter = saved;
        _domains = domains;
        _loadingDomains = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDomains = false;
        _loadError = e.message;
      });
    }
  }

  static const _titles = ['What is wrong', 'Where and proof', 'A few details'];

  bool get _canAdvance => switch (_step) {
        0 => _draft.step1Valid,
        1 => _draft.step2Valid,
        _ => _draft.step3Valid,
      };

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Remember the reporter details for next time, and tell the server —
      // neither is allowed to block the report itself.
      if (!_draft.reporter.isEmpty || _draft.reporter.type != 'CITIZEN') {
        await ReporterStore.save(_draft.reporter);
        try {
          await widget.api.updateReporter(_draft.reporter);
        } on ApiException {
          // Not worth failing a report over.
        }
      }

      final problem = await widget.api.submitProblem(
        problemId: _draft.problemId,
        title: _draft.title.trim(),
        description: _draft.description.trim(),
        domain: _draft.domain,
        districtCode: _draft.districtCode,
        locationLabel: _draft.locationLabel,
        latitude: _draft.latitude,
        longitude: _draft.longitude,
        peopleAffected: _draft.peopleAffected,
        durationLabel: _draft.durationLabel,
        consent: _draft.consent,
      );

      // Attachments go up one at a time; a failed photo must not discard a
      // report the server has already accepted.
      var failed = 0;
      for (final a in _draft.attachments) {
        try {
          await widget.api.uploadMedia(
            problemId: problem.problemId,
            filePath: a.path,
            kind: a.kind,
          );
        } catch (_) {
          failed++;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SubmittedPage(
            api: widget.api,
            problem: problem,
            failedUploads: failed,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: e.isRateLimited ? AppColors.warning : AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_step]),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _submitting ? null : _back,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  minHeight: 3,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Step ${_step + 1} of 3', style: t.bodySmall),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _back,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (_canAdvance && !_submitting) ? _next : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step < 2 ? 'Next' : 'Submit report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingDomains) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _domains.isEmpty) {
      return ErrorView(
        message: _loadError!,
        onRetry: () {
          setState(() {
            _loadingDomains = true;
            _loadError = null;
          });
          _bootstrap();
        },
      );
    }

    void refresh() => setState(() {});
    return switch (_step) {
      0 => StepWhat(draft: _draft, domains: _domains, onChanged: refresh),
      1 => StepWhere(draft: _draft, api: widget.api, onChanged: refresh),
      _ => StepDetails(draft: _draft, onChanged: refresh),
    };
  }

  Future<void> _confirmDiscard() async {
    if (_draft.title.isEmpty && _draft.attachments.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this report?'),
        content: const Text('What you have typed will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep writing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }
}
