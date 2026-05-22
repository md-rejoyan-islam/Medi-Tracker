import 'package:flutter/material.dart';

import '../main.dart' show rootNavigatorKey;
import '../services/in_app_reminder_watcher.dart';
import '../widgets/premium_nav_bar.dart';
import 'dashboard_screen.dart';
import 'drawers_screen.dart';
import 'history_screen.dart';
import 'medications_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav shell with the five spec MVP destinations. The original BLE
/// scanner is accessible from Settings → BLE toolbox.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final InAppReminderWatcher _watcher;

  static const _tabs = <Widget>[
    DashboardScreen(),
    MedicationsScreen(),
    DrawersScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _watcher = InAppReminderWatcher(rootNavigatorKey)..start();
  }

  @override
  void dispose() {
    _watcher.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: PremiumNavBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          PremiumNavDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Dashboard',
          ),
          PremiumNavDestination(
            icon: Icons.medication_outlined,
            selectedIcon: Icons.medication,
            label: 'Meds',
          ),
          PremiumNavDestination(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Drawers',
          ),
          PremiumNavDestination(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            label: 'History',
          ),
          PremiumNavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
