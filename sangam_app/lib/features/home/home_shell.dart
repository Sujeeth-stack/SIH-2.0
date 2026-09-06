import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../dashboard/dashboard_page.dart';
import '../track/my_reports_page.dart';
import 'home_page.dart';

/// Three tabs, labels always visible. No fourth tab and no drawer — the whole
/// app has to be legible to someone using it for the first time.
class HomeShell extends StatefulWidget {
  final SangamApi api;

  /// Called from Settings when the reporter points the app at a new server.
  final ValueChanged<String>? onServerChanged;

  const HomeShell({super.key, required this.api, this.onServerChanged});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _homeKey = GlobalKey<HomePageState>();
  final _reportsKey = GlobalKey<MyReportsPageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();

  void _select(int i) {
    setState(() => _index = i);
    // Each tab re-reads from the server when it comes forward, so a report
    // sent on one tab shows up on the next without a manual pull.
    switch (i) {
      case 0:
        _homeKey.currentState?.refresh();
      case 1:
        _reportsKey.currentState?.refresh();
      case 2:
        _dashboardKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            key: _homeKey,
            api: widget.api,
            onSeeAllReports: () => _select(1),
            onServerChanged: widget.onServerChanged,
          ),
          MyReportsPage(key: _reportsKey, api: widget.api),
          DashboardPage(key: _dashboardKey, api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
