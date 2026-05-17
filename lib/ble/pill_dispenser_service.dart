import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/medi_store.dart';
import '../models/dose_log.dart';
import '../models/medication.dart';

/// Bridges a BLE pill dispenser to the dose log: when the device reports
/// that a slot was dispensed, the matching scheduled dose is auto-logged
/// as taken (source = device).
///
/// This is intentionally **config-driven and inert until configured**. The
/// GATT layout of a dispenser is vendor-specific, so the service UUID,
/// notify-characteristic UUID, and how to parse a "dispensed" event out of
/// the notification bytes all live in [DispenserConfig]. Supply real values
/// (see [configure]) and the link comes alive; until then [isConfigured] is
/// false and nothing is wired to the radio.
class DispenserConfig {
  const DispenserConfig({
    required this.serviceUuid,
    required this.eventCharacteristicUuid,
    required this.parseSlot,
  });

  /// Primary GATT service exposed by the dispenser.
  final String serviceUuid;

  /// Characteristic that notifies on a dispense/dose event.
  final String eventCharacteristicUuid;

  /// Maps a raw notification payload to the dispenser slot index that fired,
  /// or null if the payload isn't a dispense event. Replace with the real
  /// frame format from the device's protocol docs.
  final int? Function(List<int> bytes) parseSlot;
}

class PillDispenserService {
  PillDispenserService._();
  static final PillDispenserService instance = PillDispenserService._();

  DispenserConfig? _config;
  StreamSubscription<List<int>>? _sub;

  bool get isConfigured => _config != null;

  /// Provide the device's GATT protocol. Until called, [attach] is a no-op.
  void configure(DispenserConfig config) => _config = config;

  /// Subscribes to the dispenser's event characteristic on an already
  /// connected [device] and auto-logs doses. Safe to call when unconfigured
  /// (does nothing) so UI code doesn't need to special-case it.
  Future<void> attach(BluetoothDevice device) async {
    final config = _config;
    if (config == null) return;

    final services = await device.discoverServices(
      subscribeToServicesChanged: false,
    );
    BluetoothCharacteristic? target;
    for (final s in services) {
      if (s.uuid.str.toLowerCase() != config.serviceUuid.toLowerCase()) {
        continue;
      }
      for (final c in s.characteristics) {
        if (c.uuid.str.toLowerCase() ==
            config.eventCharacteristicUuid.toLowerCase()) {
          target = c;
          break;
        }
      }
    }
    if (target == null) return;

    await target.setNotifyValue(true);
    await _sub?.cancel();
    _sub = target.lastValueStream.listen((bytes) {
      final slot = config.parseSlot(bytes);
      if (slot != null) _onDispensed(slot);
    });
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// A slot fired: find the medication linked to that slot and log its
  /// nearest scheduled dose for today as taken-by-device.
  Future<void> _onDispensed(int slot) async {
    final store = MediStore.instance;
    Medication? med;
    for (final m in store.medications) {
      if (m.dispenserSlot == slot && m.active) {
        med = m;
        break;
      }
    }
    if (med == null) return;

    final now = DateTime.now();
    final times = med.doseTimesOn(now);
    if (times.isEmpty) return;

    // Closest scheduled time to "now" is the dose this dispense satisfies.
    times.sort((a, b) => (a.difference(now)).abs().compareTo(
          (b.difference(now)).abs(),
        ));
    await store.recordDose(
      medicationId: med.id,
      scheduledTime: times.first,
      status: DoseStatus.taken,
      source: DoseSource.device,
    );
  }
}
