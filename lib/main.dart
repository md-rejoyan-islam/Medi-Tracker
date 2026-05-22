import 'package:flutter/material.dart';

import 'data/medi_store.dart';
import 'data/settings_store.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/reminder_service.dart';

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
    return MaterialApp(
      title: 'MediTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: SettingsStore.instance.onboardingComplete
          ? const HomeShell()
          : const WelcomeScreen(),
    );
  }
}
