// Basic smoke test: the app builds and the scanner screen renders.

import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth_ble/main.dart';

void main() {
  testWidgets('App renders the BLE scanner screen', (tester) async {
    await tester.pumpWidget(const BleApp());

    expect(find.text('BLE Scanner'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
