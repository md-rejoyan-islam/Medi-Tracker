// Smoke test: the app builds and the medication tracker shell renders.

import 'dart:io';

import 'package:bluetooth_ble/data/medi_store.dart';
import 'package:bluetooth_ble/data/settings_store.dart';
import 'package:bluetooth_ble/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('meditracker_test');
    await MediStore.instance.initForTesting(tmp.path);
    await SettingsStore.instance.init();
    // Skip the Welcome + permission-onboarding screens so we land
    // directly on HomeShell for the smoke test.
    SettingsStore.instance.onboardingComplete = true;
    SettingsStore.instance.permissionsOnboardingComplete = true;
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('App renders the MediTracker shell', (tester) async {
    await tester.pumpWidget(const MediApp());
    await tester.pumpAndSettle();

    // Spec MVP bottom-nav destinations.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Meds'), findsOneWidget);
    expect(find.text('Drawers'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Empty Dashboard state.
    expect(
      find.textContaining('Nothing scheduled today'),
      findsOneWidget,
    );
  });
}
