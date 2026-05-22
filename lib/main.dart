import 'package:flutter/material.dart';

import 'data/medi_store.dart';
import 'data/settings_store.dart';
import 'screens/app_root.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

/// Process-wide navigator key so background services (e.g. the in-app
/// reminder watcher) can push routes without needing a `BuildContext`.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediStore.instance.init();
  await SettingsStore.instance.init();
  await ReminderService.instance.init();
  runApp(const MediApp());
}

class MediApp extends StatelessWidget {
  const MediApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MediTracker',
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: SettingsStore.instance.themeMode,
          home: const AppRoot(),
        );
      },
    );
  }
}
