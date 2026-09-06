import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../track/report_detail_page.dart';
import 'report_flow_page.dart';

/// The receipt. The public ID is the one thing a reporter must leave with,
/// so it is the largest thing on the screen and it can be copied in one tap.
class SubmittedPage extends StatefulWidget {
  final SangamApi api;
  final Problem problem;
  final int failedUploads;

  const SubmittedPage({
    super.key,
    required this.api,
    required this.problem,
    this.failedUploads = 0,
  });

  @override
  State<SubmittedPage> createState() => _SubmittedPageState();
}

class _SubmittedPageState extends State<SubmittedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // A single 400 ms confirmation, and nothing else moves on this screen.
    // Someone who asked the system for reduced motion gets the end state.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ref = widget.problem.publicRef;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutBack,
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 40, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                Text(
                  'Report sent',
                  textAlign: TextAlign.center,
                  style: t.headlineMedium,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Keep this ID. Anyone can use it to check what happened next.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Gap.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        ref,
                        textAlign: TextAlign.center,
                        style: t.headlineMedium?.copyWith(
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      TextButton.icon(
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: const Text('Copy ID'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: ref));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report ID copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (widget.failedUploads > 0) ...[
                  const SizedBox(height: Gap.lg),
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.failedUploads} '
                      '${widget.failedUploads == 1 ? 'file' : 'files'} could not be '
                      'uploaded. The report itself was saved.',
                      style: t.bodySmall?.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailPage(
                          api: widget.api,
                          problemId: widget.problem.problemId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Track this report'),
                ),
                const SizedBox(height: Gap.md),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportFlowPage(api: widget.api),
                      ),
                    );
                  },
                  child: const Text('Report another'),
                ),
                const SizedBox(height: Gap.md),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
