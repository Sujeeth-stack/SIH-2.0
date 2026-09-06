import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../track/report_detail_page.dart';

/// Anyone can look up any report by its printed ID. That is intentional —
/// it is what makes a paper slip handed to a neighbour still useful.
class PublicLookupPage extends StatefulWidget {
  final SangamApi api;
  const PublicLookupPage({super.key, required this.api});

  @override
  State<PublicLookupPage> createState() => _PublicLookupPageState();
}

class _PublicLookupPageState extends State<PublicLookupPage> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final ref = _controller.text.trim();
    if (ref.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final detail = await widget.api.problemByRef(ref);
      if (!mounted) return;
      setState(() => _searching = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailPage(api: widget.api, preloaded: detail),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Look up a report')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Text(
            'Enter the report ID printed on your receipt.',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'JH-DMK-000417',
              errorText: _error,
            ),
            style: const TextStyle(letterSpacing: 1.1),
          ),
          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: _searching ? null : _search,
            child: _searching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Find report'),
          ),
        ],
      ),
    );
  }
}
