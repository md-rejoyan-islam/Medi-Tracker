// Smoke test: the app builds and the medication tracker shell renders.

import 'dart:io';

import 'package:bluetooth_ble/data/medi_store.dart';
import 'package:bluetooth_ble/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('meditracker_test');
    await MediStore.instance.initForTesting(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('App renders the Medi Tracker shell', (tester) async {
    await tester.pumpWidget(const MediApp());
    await tester.pumpAndSettle();

    // Bottom navigation destinations.
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Meds'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);

    // Empty Today state.
    expect(
      find.textContaining('Nothing scheduled today'),
      findsOneWidget,
    );
  });
}
